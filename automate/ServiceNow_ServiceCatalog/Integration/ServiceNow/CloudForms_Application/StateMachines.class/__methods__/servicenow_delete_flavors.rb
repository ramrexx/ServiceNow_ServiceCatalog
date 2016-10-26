=begin
 servicenow_delete_flavors.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method deletes service_template data from a ServiceNow table via REST API
-------------------------------------------------------------------------------
   Copyright 2016 Kevin Morey <kevin@redhat.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------
=end
def log(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def call_servicenow(action, tablename='x_23655_cfme_appli_flavors', query=nil, sysid=nil, body=nil)
  require 'rest_client'
  require 'json'
  require 'base64'

  servername = nil || $evm.object['servername']
  username = nil   || $evm.object['username']
  password = nil   || $evm.object.decrypt('password')
  url = "https://#{servername}/api/now/table/#{tablename}"
  url += "/#{sysid}" if sysid
  url += "#{query}" if query

  params = {
    :method=>action, :url=>url,
    :headers=>{
      :content_type=>:json, :accept=>:json,
      :authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
  }}
  params[:payload] = body.to_json if body
  log(:info, "Calling url: #{url} action: #{action} payload: #{params}")

  snow_response = RestClient::Request.new(params).execute
  log(:info, "response headers: #{snow_response.headers}")
  log(:info, "response code: #{snow_response.code}")
  log(:info, "response: #{snow_response}")
  snow_response_hash = JSON.parse(snow_response) rescue (return snow_response)
  return snow_response_hash['result']
end

def get_table_name
  $evm.object['table_name'] ||
    'x_23655_cfme_appli_flavors'
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  provider = $evm.root['ext_management_system']

  flavors = []

  flavor_id = $evm.root['dialog_flavor_id']

  unless flavor_id.blank?
    flavors << $evm.vmdb(:flavor).find_by_id(flavor_id)
  else
    flavors = provider.flavors.select {|fl| flavor_eligible?(fl) }
  end
  raise "no flavors found: #{flavors.inspect}" if flavors.blank?

  log(:info, "Processing <#{flavors.count}> templates")
  flavors.each_with_index do |flavor, idx|
    log(:info, "flavor: #{idx} name: #{flavor.name} id: #{flavor.id}")

    # query the table for an existing record with flavor.id
    servicenow_query = call_servicenow(:get, get_table_name, "?id=#{flavor.id}")
    log(:info, "servicenow_query: #{servicenow_query.inspect}")

    #if we got back more than one record for whatever reason then get the first record
    servicenow_query = servicenow_query[0] if servicenow_query.kind_of?(Array)

    servicenow_sysid = servicenow_query['sys_id'] unless servicenow_query.blank?
    log(:info, "servicenow_sysid: #{servicenow_sysid}") if servicenow_sysid

    if servicenow_sysid
      servicenow_result = call_servicenow(:delete, get_table_name, nil, servicenow_sysid)
    end
    log(:info, "servicenow_result: #{servicenow_result}")
  end

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
