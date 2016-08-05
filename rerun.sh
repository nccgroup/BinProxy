#!/bin/bash
RUBYLIB=lib bundle exec rerun -p '**/*.rb' -- bin/binproxy "$@"
