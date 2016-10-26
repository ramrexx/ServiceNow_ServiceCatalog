=begin
 list_service_template_ids.rb

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

service_templates = $evm.vmdb(:service_template).all

service_templates.each do |st|
  dialog_hash[st.id] = "service_template: #{st.name} id: #{st.id}"
end

choose = {''=>'< all service_templates >'}
dialog_hash = choose.merge!(dialog_hash)

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
