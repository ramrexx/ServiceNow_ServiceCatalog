=begin
 servicenow_sync_miq_templates.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method sends miq_template data to a ServiceNow table via REST API
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

  snow_response = RestClient::Request.new(params).execute
  log(:info, "response headers: #{snow_response.headers}")
  log(:info, "response code: #{snow_response.code}")
  log(:info, "response: #{snow_response}")
  snow_response_hash = JSON.parse(snow_response)
  return snow_response_hash['result']
end

def get_operatingsystem(template)
  # try to get operating system information
  template.try(:operating_system).try(:product_name) ||
    template.try(:hardware).try(:guest_os_full_name) ||
    template.try(:hardware).try(:guest_os) || 'unknown'
end

def get_diskspace(template)
  # calculate allocated disk storage in GB
  diskspace = template.allocated_disk_storage
  return nil if diskspace.nil?
  return diskspace / 1024**3
end

def get_table_name(template)
  # check template for an existing table
  template.custom_get(:servicenow_miq_template_tablename) ||
    $evm.object['table_name'] ||
    'x_23655_cfme_appli_miq_template'
end

def template_eligible?(template)
  # example to only sync templates tagged with environment
  #return false if template.tags(:environment).nil?

  # disregard archived and orphaned templates
  return false if template.archived || template.orphaned
  return true
end

def set_custom_attributes(template, servicenow_result)
  now = Time.now.strftime('%Y%m%d-%H%M%S').to_s
  log(:info, "Adding custom attribute {:servicenow_miq_template_updated => #{now}}")
  template.custom_set(:servicenow_miq_template_update, now)
  log(:info, "Adding custom attribute {:servicenow_miq_template_tablename => #{get_table_name(template)}}")
  template.custom_set(:servicenow_miq_template_tablename, get_table_name(template))
  log(:info, "Adding custom attribute {:servicenow_miq_template_sysid => #{servicenow_result['sys_id']}}")
  template.custom_set(:servicenow_miq_template_sysid, servicenow_result['sys_id'].to_s)
end

def build_template_body(template)
  body_hash = {
    :cloud      => template.cloud.to_s,
    :disk_space => get_diskspace(template),
    :ems_ref    => template.ems_ref,
    :guest_os   => get_operatingsystem(template),
    :guid       => template.guid,
    :id         => template.id,
    :mem_cpu    => template.mem_cpu.to_i,
    :name       => template.name,
    :num_cpu    => template.num_cpu,
    :provider   => template.try(:ext_management_system).try(:name),
    :template   => template.template.to_s,
    :type       => template.type,
    :uid_ems    => template.uid_ems,
    :vendor     => template.vendor
  }
  log(:info, "pre compact body_hash: #{body_hash}")
  # ServiceNow does not like nil values using compact to remove them
  return body_hash.compact
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  miq_templates = []

  if $evm.root['service_template_provision_task'] || $evm.root['service']
    miq_template_id = $evm.root['dialog_miq_template_id']
    unless miq_template_id.blank?
      miq_templates << $evm.vmdb(:miq_template).find_by_id(miq_template_id)
    else
      miq_templates = $evm.vmdb(:miq_template).all.select {|st| service_template_eligible?(st) }
    end
  elsif $evm.root['vm'].nil?
    miq_templates = $evm.vmdb(:miq_template).all.select {|t| template_eligible?(t) }
  else
    miq_templates << $evm.root['vm']
  end
  raise "no miq_templates found: #{miq_templates.inspect}" if miq_templates.blank?

  log(:info, "Processing <#{miq_templates.count}> templates")
  miq_templates.each_with_index do |template, idx|
    log(:info, "template: #{idx} name: #{template.name} id: #{template.id} vendor: #{template.vendor}")
    body_hash = build_template_body(template)
    servicenow_sysid = template.custom_get(:servicenow_miq_template_sysid)
    if servicenow_sysid
      servicenow_result = call_servicenow(:put, get_table_name(template), servicenow_sysid, body_hash)
    else
      servicenow_result = call_servicenow(:post, get_table_name(template), nil, body_hash)
    end
    set_custom_attributes(template, servicenow_result)
  end

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
