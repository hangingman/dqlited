# dqlited

A tool for running dqlite.

Adapted from [dqlite-demo](https://github.com/canonical/go-dqlite/tree/master/cmd/dqlite-demo).

This tool enables running a cluster of dqlite servers and executing queries against them. Additionally, it provides a web API similar to [rqlite](https://github.com/rqlite/rqlite), making it easier to work with Python ORMs.

## Features
- Run and manage a cluster of dqlite servers.
- Execute SQL queries via a web API.
- Support for Python ORMs through an initial implementation of a web API.

## Development

### Prerequisites

Ensure you have the following dependencies installed on your system for development:

```bash
$ sudo apt-get install libdqlite-dev libraft-dev
$ go install github.com/go-task/task/v3/cmd/task@latest
```

```bash
$ git clone https://github.com/hangingman/dqlited.git
$ cd dqlited
```

TBD

## License
This project is licensed under the BSD 2-Clause License - see the LICENSE file for details.
