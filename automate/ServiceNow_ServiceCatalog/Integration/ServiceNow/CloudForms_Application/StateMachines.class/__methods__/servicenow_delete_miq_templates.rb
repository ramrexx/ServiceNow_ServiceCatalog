=begin
 servicenow_delete_miq_templates.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method delete miq_template data from ServiceNow via REST API
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

def call_servicenow(action, tablename='x_23655_cfme_appli_miq_template', sysid=nil, body=nil)
  require 'rest_client'
  require 'json'
  require 'base64'

  servername = nil || $evm.object['servername']
  username = nil   || $evm.object['username']
  password = nil   || $evm.object.decrypt('password')
  url = "https://#{servername}/api/now/table/#{tablename}"
  url += "/#{sysid}" if sysid

  params = {
    :method=>action, :url=>url,
    :headers=>{
      :content_type=>:json, :accept=>:json,
      :authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
  }}
  params[:payload] = body.to_json if body
  log(:info, "Calling url: #{url} action: #{action} payload: #{params}")
  begin

    snow_response = RestClient::Request.new(params).execute
    log(:info, "response headers: #{snow_response.headers}")
    log(:info, "response code: #{snow_response.code}")
    log(:info, "response: #{snow_response}")
    return snow_response
  rescue RestClient::ResourceNotFound => notfound
    log(:warn, "record is missing: #{notfound}")
  end
end

def get_table_name(template)
  # check template for an existing table
  template.custom_get(:servicenow_miq_template_tablename) ||
    $evm.object['table_name'] ||
    'x_23655_cfme_appli_miq_template'
end

def set_custom_attributes(template, servicenow_result)
  log(:info, "Removing custom attribute {:servicenow_miq_template_updated => nil}")
  template.custom_set(:servicenow_miq_template_update, nil)
  log(:info, "Adding custom attribute {:servicenow_miq_template_tablename => nil}")
  template.custom_set(:servicenow_miq_template_tablename, nil)
  log(:info, "Adding custom attribute {:servicenow_miq_template_sysid => nil}")
  template.custom_set(:servicenow_miq_template_sysid, nil)
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  miq_templates = []

  if $evm.root['service_template_provision_task'] || $evm.root['service']
    miq_template_id = $evm.root['dialog_miq_template_id']
    unless miq_template_id.blank?
      miq_templates << $evm.vmdb(:miq_template).find_by_id(miq_template_id)
    else
      miq_templates = $evm.vmdb(:miq_template).all
    end
  elsif $evm.root['vm'].nil?
    miq_templates = $evm.vmdb(:miq_template).all
  else
    miq_templates << $evm.root['vm']
  end
  raise "no miq_templates found: #{miq_templates.inspect}" if miq_templates.blank?

  log(:info, "Processing <#{miq_templates.count}> templates")
  miq_templates.each_with_index do |template, idx|
    log(:info, "template: #{idx} name: #{template.name} id: #{template.id} vendor: #{template.vendor}")
    servicenow_sysid = template.custom_get(:servicenow_miq_template_sysid)
    if servicenow_sysid
      servicenow_result = call_servicenow(:delete, get_table_name(template), servicenow_sysid)
    end
    set_custom_attributes(template, servicenow_result)
  end

  if $evm.root['service_template_provision_task']
    $evm.root['service_template_provision_task'].destination.remove_from_vmdb
  end

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
