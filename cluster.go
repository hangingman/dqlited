package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"text/tabwriter"
	"time"

	dqlite "github.com/canonical/go-dqlite"
	dqclient "github.com/canonical/go-dqlite/client"
	"github.com/pkg/errors"
)

var (
	defaultCluster = []string{
		"127.0.0.1:9181",
		"127.0.0.1:9182",
		"127.0.0.1:9183",
	}
)

// Assign sets a new role for a node
func Assign(id uint64, role dqclient.NodeRole, timeout time.Duration, cluster []string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	client, err := getLeader(timeout, cluster)
	if err != nil {
		return err
	}
	defer client.Close()
	return client.Assign(ctx, id, role)
}

// Transfer tries to transfer leadership to a new role
func Transfer(id uint64, timeout time.Duration, cluster []string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	client, err := getLeader(timeout, cluster)
	if err != nil {
		return err
	}
	defer client.Close()
	return client.Transfer(ctx, id)
}

// exists checks to see if the node already exists
func exists(client *dqclient.Client, id uint64, address string) bool {
	ctx := context.Background() // TODO: timeout needed (better -- pass ctx in)
	nodes, err := client.Cluster(ctx)
	if err != nil {
		panic(errors.Wrap(err, "can't get cluster"))
	}

	for _, node := range nodes {
		if node.ID == id {
			if address != node.Address {
				const msg = "mismatched addresses for node: %d (%q vs. %q)"
				panic(fmt.Sprintf(msg, id, address, node.Address))
			}
			return true
		}
	}
	return false
}

// TODO: make id a uint64 and stop casting inside function
func nodeStart(id int, role NodeRole, add bool, dir, address string, timeout time.Duration, cluster ...string) error {
	if id == 0 {
		return fmt.Errorf("ID must be greater than zero")
	}
	var bind string
	if address == "" {
		address = fmt.Sprintf("127.0.0.1:918%d", id)
		bind = address
		log.Printf("using default address: %q\n", address)
	} else {
		// we need to bind this address, so if it is name, we need to resolve it
		// TODO: easy sanity check to see if it's already a numeric address
		host, port, err := net.SplitHostPort(address)
		if err != nil {
			return errors.Wrapf(err, "failed to split address: %q", address)
		}
		ipaddr, err := net.ResolveIPAddr("ip", host)
		if err != nil {
			return errors.Wrapf(err, "failed to resolve host: %q", host)
		}
		bind = net.JoinHostPort(ipaddr.String(), port)
		log.Println("bind address is now:", bind)
	}
	log.Printf("creating node: %d @ %s -- listening on %q (ip:%s)\n", id, address, bind, myIP())
	log.Printf("cluster: %v\n", cluster)
	dir = filepath.Join(dir, fmt.Sprint(id))
	if err := os.MkdirAll(dir, 0755); err != nil {
		return errors.Wrapf(err, "can't create dir %s", dir)
	}
	node, err := dqlite.New(
		uint64(id), address, dir,
		dqlite.WithBindAddress(bind),
		dqlite.WithNetworkLatency(defaultNetworkLatency),
	)
	if err != nil {
		return errors.Wrap(err, "failed to create node")
	}

	log.Printf("starting node: %d\n", id)
	if err := node.Start(); err != nil {
		return errors.Wrap(err, "failed to start node")
	}
	/*
		const wait = 1 * time.Second
		log.Printf("we're waiting %s for node to start\n", wait)
		time.Sleep(wait)
		log.Printf("ok get node leader via cluster: %s\n", cluster)
	*/
	client, err := getLeader(timeout, cluster)
	if err != nil {
		//log.Println("CRAPOLA:", err)
		return errors.Wrap(err, "can't connect to cluster leader")
	}
	if add {
		if exists(client, uint64(id), address) {
			log.Printf("node %d (%s) previously added. Skipping add", id, address)
			add = false
		}
	}
	if add {
		info := dqclient.NodeInfo{
			ID:      uint64(id),
			Address: address,
			Role:    dqclient.NodeRole(role),
		}

		// TODO: make configurable
		const addTimeout = time.Second * 10
		ctx, cancel := context.WithTimeout(context.Background(), addTimeout)
		defer cancel()

		log.Printf("add mode with timeout of: %s\n", addTimeout)
		if err := client.Add(ctx, info); err != nil {
			log.Printf("error adding node: %d (%s) to cluster: %v\n", id, address, err)
			return errors.Wrapf(err, "can't add node id: %d", id)
		}
	} else {
		log.Printf("skipping adding server: %d to cluster\n", id)
	}

	// if we are killed, inform the remainder of the cluster
	sig := make(chan os.Signal)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	go func() {
		bye := <-sig
		log.Printf("server id: %d is shutting down on signal: %v\n", id, bye)

		/*
			// Check if leader and transfer if we are
			if err := client.Remove(context.Background(), uint64(id)); err != nil {
				log.Printf("error removing cluster id:%d error:%v\n", id, err)
			} else {
				log.Printf("removed self from cluster (id:%d)\n", id)
			}
			if err := node.Close(); err != nil {
				log.Println("failed to stop node:", err)
			}
		*/
		log.Printf("server id: %d has shut down\n", id)
		os.Exit(0)
	}()

	log.Printf("node %d has been started\n", id)
	return nil
}

// NodeRole is a go-dqlite Node role (e.g., voter, standby, or spare)
type NodeRole dqclient.NodeRole

const (
	// Voter node will replicate data and participate in quorum
	//Voter = NodeRole(0)
	Voter = NodeRole(dqclient.Voter)

	// Standby node will replicate data but won't participate in quorum
	Standby = NodeRole(1)

	// Spare node won't replicate data and won't participate in quorum
	Spare = NodeRole(2)
)

func nodeRole(s string) (NodeRole, error) {
	switch strings.ToLower(s) {
	case "voter":
		return Voter, nil
	case "standby":
		return Standby, nil
	case "spare":
		return Spare, nil
	}
	return NodeRole(255), fmt.Errorf("invalid role name: %q", s)
}

func clusterShow(address string, timeout time.Duration, cluster ...string) error {
	client, err := getLeader(timeout, cluster)
	if err != nil {
		return errors.Wrap(err, "can't connect to cluster leader")
	}
	defer client.Close()

	// TODO: make timeout configurable?
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	leader, err := client.Leader(ctx)
	if err != nil {
		return errors.Wrap(err, "can't get leader")
	}

	nodes, err := client.Cluster(ctx)
	if err != nil {
		return errors.Wrap(err, "can't get cluster")
	}

	flags := tabwriter.TabIndent

	tw := tabwriter.NewWriter(
		os.Stdout, // io.Writer
		0,         // min width
		0,         // tab width
		1,         // padding
		' ',       // pad character
		flags,     // behavior flags
	)

	fmt.Fprintf(tw, "ID \tRole \tLeader \tAddress\n")
	for _, node := range nodes {
		isLeader := node.ID == leader.ID
		fmt.Fprintf(tw, "%d \t%s \t%t \t%s\n", node.ID, node.Role, isLeader, node.Address)
	}
	tw.Flush()
	return nil
}

// add node <id> to <cluster>
func clusterAdd(id int, address string, timeout time.Duration, cluster []string) error {
	if id < 1 {
		return fmt.Errorf("ID must be greater than zero")
	}
	if address == "" {
		return errors.New("address cannot be blank")
	}
	info := dqclient.NodeInfo{
		ID:      uint64(id),
		Address: address,
	}

	client, err := getLeader(timeout, cluster)
	if err != nil {
		return errors.Wrap(err, "can't connect to cluster leader")
	}
	defer client.Close()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	if err := client.Add(ctx, info); err != nil {
		return errors.Wrap(err, "can't add node")
	}

	return nil
}

const defaultNetworkLatency = 20 * time.Millisecond

// listen for SIGUSR2 and dump cluster info to log
func dumper(client *dqclient.Client) {
	ch := make(chan os.Signal)
	signal.Notify(ch, syscall.SIGUSR2)

	go func(cc chan os.Signal) {
		ctx := context.Background()
		for {
			<-cc
			leader, err := client.Leader(ctx)
			if err != nil {
				log.Println("leader error:", err)
			} else {
				log.Println("LEADER:", leader)
			}

			nodes, err := client.Cluster(ctx)
			if err != nil {
				log.Println("cluster error:", err)
				continue
			}
			for _, node := range nodes {
				log.Println(node)
			}
		}
	}(ch)
}
