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

require 'securerandom'
require 'webmock/rspec'
require 'active_support/time'

def random_integer
  SecureRandom.random_number(1000000)
end

def random_issue
  {
    id: random_integer,
    iid: random_integer,
    project_id: random_integer,
    title: random_string,
    description: random_string,
    created_at: Time.now - 1.week,
    updated_at: Time.now - 1.day,
    type: random_string,
    web_url: "https://gitlab.com/#{random_string}",
  }
end

def random_issue_document
  {
    id: random_integer,
    gitlab_id: random_integer,
    project_id: random_integer,
    title: random_string,
    description: random_string,
    created_at: Time.now - 1.week,
    updated_at: Time.now - 1.day,
    type: 'issue',
    url: "https://gitlab.com/#{random_string}",
  }
end

def random_merge_request
  {
    id: random_integer,
    iid: random_integer,
    project_id: random_integer,
    title: random_string,
    description: random_string,
    created_at: Time.now - 1.week,
    updated_at: Time.now - 1.day,
    web_url: "https://gitlab.com/#{random_string}",
  }
end

def random_merge_request_document
  {
    id: random_integer,
    gitlab_id: random_integer,
    project_id: random_integer,
    title: random_string,
    description: random_string,
    created_at: Time.now - 1.week,
    updated_at: Time.now - 1.day,
    url: "https://gitlab.com/#{random_string}",
    type: 'merge request'
  }
end

def random_project
  {
    id: random_integer,
    name: random_string,
    description: random_string,
    created_at: Time.now - 1.week,
    last_activity_at: Time.now - 1.day,
    web_url: "https://gitlab.com/#{random_string}",
    readme_url: "https://gitlab.com/#{random_string}/README.md"
  }
end

def random_readme
  {
    blob_id: random_string,
    file_name: 'README.md',
    size: random_integer,
    encoding: 'base64',
    content: Base64.encode64(random_string)
  }
end

def random_readme_document
  {
    id: random_string,
    project_id: random_integer,
    name: 'README.md',
    description: "#{random_string} README",
    content: random_string
  }
end

def random_string
  SecureRandom.hex
end