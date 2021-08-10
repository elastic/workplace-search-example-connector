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

require 'spec_helper'
require_relative '../bootstrap'

describe 'bootstrap' do
  let(:host) { "https://#{random_string}.com" }
  let(:name) { random_string }
  let(:username) { random_string }
  let(:password) { random_string }

  it 'should create the content source' do
    id = expect_create_content_source

    actual_content_source = run_bootstrap

    expect(actual_content_source.id).to(eq(id))
  end

  it 'can prompt for the user password' do
    allow(STDIN).to(receive(:getpass)).and_return(password)
    expect_create_content_source

    expect(
      bootstrap(host: host, username: username, name: name)
    ).to(be)
  end

  it 'should fail if the create call fails' do
    when_create_content_source
      .and_return(status: 500)

    expect {
      run_bootstrap
    }.to(raise_error(/because 500/))
  end

  def expect_create_content_source
    id = random_string
    when_create_content_source
      .and_return(
        status: 200,
        body: {
          id: id,
          name: name
        }.to_json
      )
    id
  end

  def run_bootstrap
    bootstrap(host: host, username: username, password: password, name: name)
  end

  def when_create_content_source
    stub_request(:post, "#{host}/api/ws/v1/sources")
      .with(
        body: {
          name: name,
          schema: {
            name: 'text',
            description: 'text',
            created_at: 'date',
            last_activity_at: 'date',
            url: 'text',
            content: 'text',
            project_id: 'text',
            gitlab_id: 'text'
          },
          display: {
            title_field: 'name',
            description_field: 'description',
            url_field: 'url',
            detail_fields: [
              { field_name: 'description', label: 'Description' },
              { field_name: 'content', label: 'Content' },
              { field_name: 'created_at', label: 'Created At' },
              { field_name: 'last_activity_at', label: 'Updated At' },
            ]
          }
        }.to_json,
        headers: {
          'Authorization' => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
        }
      )
  end
end