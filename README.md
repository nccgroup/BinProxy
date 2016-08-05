## Overview

BinProxy is a proxy for arbitrary TCP connections.  You can define custom message
formats using the [BinData] gem.

[BinData]: https://github.com/dmendel/bindata/wiki

## Installation

### Prerequisites

* Ruby 2.3 or later
* A C compiler, Ruby headers, etc., are needed to compile several
  dependencies.
  * On Ubuntu, `sudo apt install build-essential ruby-dev` should do it.
  * If you've installed a custom Ruby (e.g. with RVM), you probably already
    have what you need.
* `openssl` binary for `--tls` without an explicit cert/key.
* To build the UI, node.js and npm.  (Not needed at runtime)

### From Gemfile

(Coming soon)
Run `gem install binproxy-0.6.gem`.  You may need to use `sudo`, depending on
your Ruby installation.

### From Source

~~~sh
git clone https://github.com/nccgroup/BinProxy.git binproxy
cd binproxy

# Install ruby dependencies.
# Depending on your setup, one or both of these may require sudo.
gem install bundler && bundle

# The UI is built with a webpack/babel toolchain:
(cd ui && npm install) \
  && rake build-ui

# Confirm that everything works
# run.sh sets up the environment and passes all args to binproxy
./run.sh --help
~~~

To build and install the gem package:

~~~sh
gem build binproxy.gemspec

# Again, you may need sudo here
gem install binproxy-1.0.0.gem
~~~

Bug reports on installation issues are welcome!

## Usage

### Basic Usage

1. Run `binproxy` with no arguments.
2. Browse to http://localhost:4567/
3. Enter local and remote hostnames or IP addresses and ports, and click
   'update'
4. Point a client at the local service, and watch the packets flow.

### Command Line Flags

See `--help` for the complete list, but in short:

~~~sh
binproxy -c <class> [<local-host>] <local-port> <remote-host> <remote-port>
~~~

If you leave out the `-c` argument, a simple hex dump is shown.

If you leave out the local host, binproxy assumes localhost.

With the `--socks-proxy` or `--http-proxy` options, the remote host and port
are determined dynamically, and should not be specified.

#### Examples

~~~sh
# Proxy from localhost:9000 -> example.com:9000
binproxy localhost 9000 example.com 9000

# Act as a SOCKS proxy on localhost:1080
# MITM and unwrap TLS on the proxied traffic, using a self-signed cert and key
binproxy -S --tls 1080

# "Poor substitute for Burp" mode:
#
# HTTP proxy; MITM TLS w/ pre-generated cert; simple header parsing
# Note: this will only work on HTTPS traffic, not plain HTTP!
# If you're working with the source repo, you generate the certs with:
#   rake makecert[example.com]
# And then import certs/ca-cert.pem into your browser or OS's trust store.
binproxy -H --tls \
  --tls-cert certs/example.com-cert.pem \
  --tls-key certs/example.com-key.pem \
  --class-name DumbHttp::Message \
  localhost 8080
~~~

### Customizing

By default, the proxy uses the built-in RawMessage class, which just gives
you a hexdump of each message (assuming 1:1 between messages and TCP packets)

You can view parsed protocol information by specifying a BinData::Record
subclass† with the `--class` command line argument.

You may also wish to define the following in your class:

~~~ruby
def summary
  # return a single-line description of this record
end

# currently supported options are
#   - nil : use default display
#   - "anon" : for structs, show contents directly
#   - "hex" : for numbers, display as 0x1234ABCD
#   - "hexdump" : for strings, display like `hexdump -C`
default_parameter display_as: "..."

# TODO: document state stuff
def self.initial_state
end

def current_state
end

def update_state
end
~~~

† Technically, any subclass of BinData::Base will work.

## Dynamic Proxying

By default, BinProxy relays all traffic to a static upstream host and port.
It can also be configured to act as a SOCKS (v4 or v4a) or HTTP proxy with
the `--socks-proxy` and `--http-proxy` flags, respectively.

**Note:** Currently, the HTTP proxy only supports connections tunneled with
the HTTP `CONNNECT` verb; it cannot proxy raw HTTP `GET`, `POST`, etc.,
requests.  In practice, this means that HTTPS traffic will work, but plain
HTTP traffic will not unless the client supports a flag to force tunneling,
like `curl -p`.

## TLS / SSL

Use the `--tls` flag to unwrap TLS encryption before processing messages.  By
default, BinProxy will generate a self-signed certificate.  You can sepecify
PEM files containing a certificate and key with `--tls-cert` and `--tls-key`.
(If you've cloned the source repo, use `rake makecert[example.com]` to
generate a static CA and a certificate with the appropriate hostname.)

## Known issues

- The HTTP proxy functionality was thrown together at the last minute and is
  not particularly robust.

See also the `TODO` file for random ideas and wishlist items.

### Credits

BinProxy's core TCP proxy functionality originated in a special purpose proxy
written by Sean Devlin.  Rusty Burchfield contributed the HTML UI for that
proxy.  While enough of the code has changed that they can no longer be
blamed for any current bugs, BinProxy likely wouldn't exist without both of
their work.
