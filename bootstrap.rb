# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'io/console'
require 'slop'
require_relative 'lib/content_source'

def bootstrap(options)
  password = options[:password] || STDIN.getpass("Password: ")
  ContentSource.create(
    host: options[:host],
    username: options[:username],
    password: password,
    name: options[:name])
end

def parse_options
  Slop.parse do |o|
    o.string '-h', '--host', 'The Workplace Search host', required: true
    o.string '-n', '--name', 'The name of the content source to create. Only required when bootstrapping.', required: true
    o.string '-p', '--password', 'The password to authenticate with Workplace Search. If omitted then you will be prompted to enter.'
    o.string '-u', '--username', 'The username to authenticate with Workplace Search', required: true
  end
end

if $0 == __FILE__
  content_source = bootstrap(parse_options)
  puts "Created ContentSource with ID #{content_source.id}. You may now begin indexing with '--content-source-id=#{content_source.id}'"
end