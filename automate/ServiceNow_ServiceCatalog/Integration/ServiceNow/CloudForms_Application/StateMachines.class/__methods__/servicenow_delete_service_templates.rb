=begin
 servicenow_delete_service_templates.rb

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

def call_servicenow(action, tablename='x_23655_cfme_appli_service_templates', query=nil, sysid=nil, body=nil)
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
    'x_23655_cfme_appli_service_templates'
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  if $evm.root['service_template_provision_task'] || $evm.root['service']
    service_template_id = $evm.root['dialog_service_template_id']
    unless service_template_id.blank?
      service_templates = []
      service_templates << $evm.vmdb(:service_template).find_by_id(service_template_id)
    else
      service_templates = $evm.vmdb(:service_template).all
    end
  else
    service_templates = $evm.vmdb(:service_template).all
  end
  raise "no service_templates found: #{service_templates.inspect}" if service_templates.blank?

  log(:info, "service_templates: #{service_templates}")


  log(:info, "Processing <#{service_templates.count}> templates")
  service_templates.each_with_index do |service_template, idx|
    log(:info, "service_template: #{idx} name: #{service_template.name} id: #{service_template.id}")

    # query the table for an existing record with service_template.id
    servicenow_query = call_servicenow(:get, get_table_name, "?id=#{service_template.id}")
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

  if $evm.root['service_template_provision_task']
    $evm.root['service_template_provision_task'].destination.remove_from_vmdb
  end

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
