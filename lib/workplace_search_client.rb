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

class WorkplaceSearchClient

  def initialize(
    host:,
    access_token:,
    search_access_token: nil
  )
    @host = host
    @access_token = access_token
    @search_access_token = search_access_token
  end

  def get(path)
    with_auth.get("#{@host}#{path}")
  end

  def post(path, json)
    with_auth
      .post(
        "#{@host}#{path}",
        json: json
      )
  end

  def search(query)
    with_auth(@search_access_token)
      .post(
        "#{@host}/api/ws/v1/search",
        json: query
      )
  end

  private

  def with_auth(access_token = @access_token)
    HTTP.auth("Bearer #{access_token}")
  end
end