#!/bin/sh
set -x
RUBY_LIB=lib bundle exec bin/binproxy $@
