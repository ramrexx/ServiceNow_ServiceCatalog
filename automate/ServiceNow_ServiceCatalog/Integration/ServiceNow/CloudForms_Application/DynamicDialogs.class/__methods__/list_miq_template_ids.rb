=begin
 list_miq_template_ids.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method lists service_template ids 
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

dialog_hash = {}

miq_templates = $evm.vmdb(:miq_template).all

miq_templates.each do |t|
  next if t.archived || t.orphaned
  next unless t.ext_management_system
  dialog_hash[t.id] = "template: #{t.name} id: #{t.id} on provider: #{t.ext_management_system.name}"
end

choose = {''=>'< all templates >'}
dialog_hash = choose.merge!(dialog_hash)

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
