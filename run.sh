#!/bin/bash
ruby demo.rb generate_test_data

# time of first run will be thrown off by disk caching, so discard
ruby demo.rb calculate > /dev/null

ruby demo.rb calculate
ruby demo.rb calculate lazy
