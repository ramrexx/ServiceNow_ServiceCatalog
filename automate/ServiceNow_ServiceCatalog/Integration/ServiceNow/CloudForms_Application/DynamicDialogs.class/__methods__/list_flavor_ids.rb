=begin
 list_flavor_ids.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method lists Cloud flavor ids
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

$evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}

dialog_hash = {}

# see if provider is already set in root
provider = $evm.root['ext_management_system']

if provider
  provider.flavors.each do |flavor|
    next unless flavor.ext_management_system || flavor.enabled
    dialog_hash[flavor.id] = "#{flavor.name} on #{flavor.ext_management_system.name}"
  end
end

choose = {''=>'< all flavors >'}
dialog_hash = choose.merge!(dialog_hash)

$evm.object["values"]     = dialog_hash
log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
