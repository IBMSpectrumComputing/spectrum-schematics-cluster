# IBM Spectrum Symphony CWS/LSF Cluster Template

A High Performance Computing (HPC) for FSS(Financial Services Sector) Tech Preview

This repository can be forked or directly used in IBM Cloud Schematics. You simply update terraform.tfvars to provide your software entitlement and/or sensitive info (bluemix api key, softlayer username and softlayer api key, for security concern, you should use Schematics GUI for them), you can also fine control with other terraform variables.

**IMPORTANT**

Due to legal requirement, we can not provide product packages and entitlement here. You need to provide your own packages and entitlement or you can get the evaluation packages and entitlements from **IBM Website**
- Evaluation: symphony latest (7.2.0.0): https://www.ibm.com/marketing/iwm/iwm/web/preLogin.do?source=swerpzsw-symphony-3
  - uri_file_entitlement   = "https://......./sym_adv_ev_entitlement.dat"
  - uri_package_installer  = "https://......./symeval-7.2.0.0_x86_64.bin"
  - uri_package_additonal  = "https://......./symdeeval-7.2.0.0_x86_64.bin"
- Evaluation: cws latest (2.2.0.0): https://www.ibm.com/marketing/iwm/iwm/web/preLogin.do?source=swg-eipcfs
  - uri_file_entitlement   = "https://......./cwseval_entitlement.dat"
  - uri_package_installer  = "https://......./seval-2.2.0.0_x86_64.bin"
- Evaluation: lsf latest (10.1): https://www.ibm.com/marketing/iwm/iwm/web/preLogin.do?source=swerpsysz-lsf-3&S_PKG=lsfv101
  - uri_file_entitlement   = "" (no evaluation license provided, provide your own)
  - uri_package_installer  = "https://......./lsf10.1_lsfinstall_linux_x86_64.tar.Z"
  - uri_package_additional = "https://......./lsf10.1_linux2.6-glibc2.3-x86_64.tar."
  - uri_package_additional2= "" (no evaluation copy provided, does not support ubuntu 1604)

The entitlement can be provided by **either** of below:
- entitlement (string value, paste entitlement content)
- uri_file_entitlement (the url that is publicly available, an example is the url when you request evaluation on developerworks)

The packages can be provided by combination of below:
- uri_package_installer (required, the url that is publicly available, an example is the url when you request evaluation on developerworks)
- uri_package_additional (optional for cws, required for symphony development host, required for lsf. the url that is publicly available, an example is the url when you request evaluation pointing to symphony developer edition or lsf arch linux2.6-glibc2.3-x86_64)
- uri_package_additonal2 (optional for cws and symhony, required for lsf to support ubuntu1604. the url that is publicly available, an example is the url when you request evaluation pointing to lsf arch lnx310-lib217-x86_64)

## Release Information

* IBM Spectrum Symphony/CWS/LSF Cluster on Schematics
* Supported Product Version: symphony latest(7.2.0.0), cws latest(2.2.0.0), lsf latest(10.1)

## Contents

* Default Topology
* Introduction
* Usage
* Release Notes
* Advanced Usage
* Available Datacenters
* Community Contribution
* Copyright
 
## Default Topoloty

### default symphony cluster

![default installation topology](https://raw.githubusercontent.com/IBMSpectrumComputing/spectrum-schematics-cluster/master/images/symdefault.png)

### default cws cluster

![default installation topology](https://raw.githubusercontent.com/IBMSpectrumComputing/spectrum-schematics-cluster/master/images/cwsdefault.png)

### default lsf cluster

![default installation topology](https://raw.githubusercontent.com/IBMSpectrumComputing/spectrum-schematics-cluster/master/images/lsfdefault.png)

## Introduction

To use IBM schematics or Terraform with IBM Cloud Provider, you need to gain certain information, here is the most important ones

- **ibm_bmx_api_key**
  - your api key for IBM Bluemix
  - If you do not have an existing API key, you can generate the value by running bluemix iam api-key-create NAME
- **ibm_sl_username** and **ibm_sl_api_key**
  - your username and api key for SoftLayer
  - You can retrieve the value from the "SoftLayer Customer Portal", "account" -> "User"
- **ssh_public_key**
  - your personal ssh public key to access servers on softlayer
  - you need to have "manage sshkey" capability on softlayer
- **entitlement** or **uri_file_entitlement**
  - entitlement that enables use of the cluster software
  - you can obtain a trial entitlement from developerworks if you do not have one
- **uri_package_installer**
  - primary installer that launches Spectrum Computing cluster software
  - you can obtain the trial copy from developerworks if you do not have one
- uri_package_additional
  - secondary installer that is used for Spectrum Computing symphony de or lsf arch linux2.6-glibc2.3-x86_64(centos7)
  - you can obtain the trial copy from developerworks if you do not have one
- uri_package_additional2
  - additional installer that is used for Spectrum Computing lsf arch lnx310-glibc217-x86_64 (ubuntu1604)
  - you can obtain the trial copy from developerworks if you do not have one

## Usage

### Usage with Terraform Binary on your local workstation
You will need to [setup up IBM Cloud provider credentials](#setting-up-provider-credentials) on your local machine. Then you will need the [Terraform binary](https://www.terraform.io/intro/getting-started/install.html) and the [IBM Cloud Provider Plugin](https://github.com/IBM-Bluemix/terraform-provider-ibm). Then follow the instructions at [https://ibm-bluemix.github.io/tf-ibm-docs/v0.5.0/#developing-locally](https://ibm-bluemix.github.io/tf-ibm-docs/v0.5.0/#developing-locally).

To run this project locally execute the following steps:

- Supply required variable values in `terraform.tfvars`, see https://www.terraform.io/intro/getting-started/variables.html#from-a-file for instructions.
  - Alternatively these values can be supplied via the command line or environment variables, see https://www.terraform.io/intro/getting-started/variables.html.
- `terraform plan`: this will perform a dry run to show what infrastructure terraform intends to create
- `terraform apply`: this will create actual infrastructure
  - Infrastructure can be seen in IBM Bluemix under the following URLs:
    - https://control.bluemix.net/devices
- `terraform destroy`: this will destroy all infrastructure which has been created

### Usage with IBM Cloud Schematics

Follow the instructions on the [Getting Started with IBM Cloud Schematics](https://console.ng.bluemix.net/docs/services/schematics/index.html#gettingstarted) documentation page.


#### steps

- login to IBM bluemix, navigate to Schematics
- create new environment
  - Source Control URL: use your forked repository url
  - Variables (required)
    - **bluemix_api_key**
    - **softlayer_username**, **softlayer_api_key**
    - **ssh_public_key**
    - **entitlement** or **uri_file_entitlement**
    - **uri_package_installer**
  - Variables (optional)
    - product = symphony|cws|lsf to create deferrent clusters, default to symphony
    - uri_package_additional
    - uri_package_additional2
    - refer to the file main.tf for full variable list
- plan and view plan log
- apply and view apply log
- attention
  - this assumes that the cluster will be created in the same private vlan
  - if for any reason it is not this case, the cluster deployment might fail, you can shrink/destroy and apply again
- (optional) to gain more control of the cluster
  - use softlayer web GUI
  - use bluemix cli
    - bluemix sl vs list
  - login to softlayer resource directly 
    - tail -f /root/log_deploy_product
- normally you should wait 10 minutes before accessing the web GUI

### all variables
|Variable Name|Description|Default Value|
|-------------|-----------|-------------|
|**bluemix_api_key**|bluemix api key||
|**softlayer_username**|softlayer username||
|**softlayer_api_key**|softlayer api key||
|datacenter|data center to create vm nodes in|dal12|
|hourly_billing_master|bill on hourly usage for master nodes|true|
|hourly_billing_compute|bill on hourly usage for compute nodes|true|
||||
|**ssh_public_key**|ssh fingerprint to access cluster nodes||
|ssh_key_label|label for your ssh public key|ssh_compute_key|
|ssh_key_note|description for your ssh public key|ssh key for cluster hosts|
||||
|**entitlement**|entitlement content to use the product||
|**uri_file_entitlement**|publically available link to the entitlement file||
|**uri_package_installer**|publically available link to the product installation file||
|uri_package_additional|publically available link to the product supplement file||
|uri_package_additional2|publically available link to the extra product supplement file||
|product|cluster product to deploy: [symphony, cws, lsf]|symphony|
|version|version of the cluster product: [latest, 7.2.0.0, 2.2.0.0, 10.1]|latest|
|cluster_admin|admin account of the cluster: [egoadmin, lsfadmin]|egoadmin|
|cluster_name|name of the cluster|mycluster|
||||
|os_refrence|operating system code to deploy: [CENTOS_7_64, UBUNTU_16_64]|CENTOS_7_64|
|domain_name|dns domain name to use|domain.com|
|prefix_master|hostname prefix for master nodes|master|
|prefix_compute|hostname prefix for compute nodes|compute|
|prefix_dehost|hostname prefix for symhony development nodes|dehost|
|number_of_compute|number of vm compute nodes|2|
|number_of_dehost|number of development nodes|1|
|network_speed_master|network interface speed for master nodes|1000|
|network_speed_compute|network interface speed for compute nodes|1000|
|core_of_master|cpu cores for master nodes|2|
|core_of_compute|cpu cores for compute nodes|1|
|memory_in_mb_master|memory for master nodes|8192|
|memory_in_mb_compute|memory for compute nodes|4096|
||||
|master_failover|enable HA for masters or not|false|
|use_intranet|cluster communicate via intranet connection|true|
|datacenter_bare_metal|data center to create bare metal nodes in|wdc04|
|master_use_bare_metal|whether create bare metal for cluster masters|false|
|fixed_config_preset|bare metal hardware configurations|S1270_32GB_2X960GBSSD_NORAID|
|os_refrence_bare_metal|operating system code to deploy on bare metal|UBUNTU_16_64|
|prefix_compute_bare_metal|hostname prefix for compute nodes|bmcompute|
|number_of_compute_bare_metal|number of bare metal compute nodes|0|

- please refer to terraform.tfvars and/or main.tf

## Release Notes

### version 0.5.0

- ssh_private_key no longer needed for bare metal deployment
- add paramters for evaluation clusters:
  - uri_file_entitlement
  - uri_package_installer
  - uri_package_additonal
  - uri_package_additional2

### version 0.4

- Boost version to 0.4 to catchup provider version
- Support **symphony**, **cws** and **lsf deployment**
- Support both **CENTOS_7_64** and **UBUNTU_16_64**
- Bare metal support (experimental)
  - **never create bare metals with the same hostname and domainname in the same day even after destroy**
  - bare metal creation require to specify datacenter and preset fixed config, no guarranty of availability
  - **master_use_bare_metal** or **number_of_compute_bare_metal**

## Advanced Usage

### use internet interface for cluster communication

- set use_intranet = false will force clusters to communicate via internet link

### bare metal support

Since datacenter and fixed_config_preset has to be specified and there is no good way to make sure the selection can be satisfied, you may need to try several times. "D2620V4_128GB_2X800GB_SSD_RAID_1_K80_GPU2" is good GPU preset

- master_use_bare_metal = true will create masters as bare metal servers
- number_of_compute_bare_metal is the quantity of bare metal compute nodes
- datacenter_bare_metal is the datacenter where to deploy bare metal servers
- os_reference_bare_metal is the operating system to deploy on bare metal servers

## Available Data Centers
Any of these values is valid for use with the `datacenter` variable:
- `ams01`: Amsterdam 1
- `ams03`: Amsterdam 3
- `che01`: Chennai 1
- `dal01`: Dallas 1
- `dal10`: Dallas 10
- `dal12`: Dallas 12
- `dal02`: Dallas 2
- `dal05`: Dallas 5
- `dal06`: Dallas 6
- `dal07`: Dallas 7
- `dal09`: Dallas 9
- `fra02`: Frankfurt 2
- `hkg02`: Hong Kong 2
- `hou02`: Houston 2
- `lon02`: London 2
- `mel01`: Melbourne 1
- `mex01`: Mexico 1
- `mil01`: Milan 1
- `mon01`: Montreal 1
- `osl01`: Oslo 1
- `par01`: Paris 1
- `sjc01`: San Jose 1
- `sjc03`: San Jose 3
- `sao01`: Sao Paulo 1
- `sea01`: Seattle 1
- `seo01`: Seoul 1
- `sng01`: Singapore 1
- `syd01`: Sydney 1
- `syd04`: Sydney 4
- `tok02`: Tokyo 2
- `tor01`: Toronto 1
- `wdc01`: Washington 1
- `wdc04`: Washington 4

## Community Contribution Requirements

Community contributions to this repository must follow the [IBM Developer's Certificate of Origin (DCO)](https://github.com/IBMSpectrumComputing/spectrum-schematics-cluster/blob/master/IBMDCO.md) process and only through GitHub Pull Requests:

 1. Contributor proposes new code to community.

 2. Contributor signs off on contributions 
    (i.e. attachs the DCO to ensure contributor is either the code 
    originator or has rights to publish. The template of the DCO is included in
    this package).
 
 3. IBM SpectrumComputing reviews contribution to check for:
    i)  Applicability and relevancy of functional content 
    ii) Any obvious issues

 4. If accepted, posts contribution. If rejected, work goes back to contributor and is not merged.

## Copyright

### EPL v1.0 

    Eclipse Public License - v 1.0

THE ACCOMPANYING PROGRAM IS PROVIDED UNDER THE TERMS OF THIS ECLIPSE
PUBLIC LICENSE ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF
THE PROGRAM CONSTITUTES RECIPIENT'S ACCEPTANCE OF THIS AGREEMENT.

*1. DEFINITIONS*

"Contribution" means:

a) in the case of the initial Contributor, the initial code and
documentation distributed under this Agreement, and

b) in the case of each subsequent Contributor:

i) changes to the Program, and

ii) additions to the Program;

where such changes and/or additions to the Program originate from and
are distributed by that particular Contributor. A Contribution
'originates' from a Contributor if it was added to the Program by such
Contributor itself or anyone acting on such Contributor's behalf.
Contributions do not include additions to the Program which: (i) are
separate modules of software distributed in conjunction with the Program
under their own license agreement, and (ii) are not derivative works of
the Program.

"Contributor" means any person or entity that distributes the Program.

"Licensed Patents" mean patent claims licensable by a Contributor which
are necessarily infringed by the use or sale of its Contribution alone
or when combined with the Program.

"Program" means the Contributions distributed in accordance with this
Agreement.

"Recipient" means anyone who receives the Program under this Agreement,
including all Contributors.

*2. GRANT OF RIGHTS*

a) Subject to the terms of this Agreement, each Contributor hereby
grants Recipient a non-exclusive, worldwide, royalty-free copyright
license to reproduce, prepare derivative works of, publicly display,
publicly perform, distribute and sublicense the Contribution of such
Contributor, if any, and such derivative works, in source code and
object code form.

b) Subject to the terms of this Agreement, each Contributor hereby
grants Recipient a non-exclusive, worldwide, royalty-free patent license
under Licensed Patents to make, use, sell, offer to sell, import and
otherwise transfer the Contribution of such Contributor, if any, in
source code and object code form. This patent license shall apply to the
combination of the Contribution and the Program if, at the time the
Contribution is added by the Contributor, such addition of the
Contribution causes such combination to be covered by the Licensed
Patents. The patent license shall not apply to any other combinations
which include the Contribution. No hardware per se is licensed hereunder.

c) Recipient understands that although each Contributor grants the
licenses to its Contributions set forth herein, no assurances are
provided by any Contributor that the Program does not infringe the
patent or other intellectual property rights of any other entity. Each
Contributor disclaims any liability to Recipient for claims brought by
any other entity based on infringement of intellectual property rights
or otherwise. As a condition to exercising the rights and licenses
granted hereunder, each Recipient hereby assumes sole responsibility to
secure any other intellectual property rights needed, if any. For
example, if a third party patent license is required to allow Recipient
to distribute the Program, it is Recipient's responsibility to acquire
that license before distributing the Program.

d) Each Contributor represents that to its knowledge it has sufficient
copyright rights in its Contribution, if any, to grant the copyright
license set forth in this Agreement.

*3. REQUIREMENTS*

A Contributor may choose to distribute the Program in object code form
under its own license agreement, provided that:

a) it complies with the terms and conditions of this Agreement; and

b) its license agreement:

i) effectively disclaims on behalf of all Contributors all warranties
and conditions, express and implied, including warranties or conditions
of title and non-infringement, and implied warranties or conditions of
merchantability and fitness for a particular purpose;

ii) effectively excludes on behalf of all Contributors all liability for
damages, including direct, indirect, special, incidental and
consequential damages, such as lost profits;

iii) states that any provisions which differ from this Agreement are
offered by that Contributor alone and not by any other party; and

iv) states that source code for the Program is available from such
Contributor, and informs licensees how to obtain it in a reasonable
manner on or through a medium customarily used for software exchange.

When the Program is made available in source code form:

a) it must be made available under this Agreement; and

b) a copy of this Agreement must be included with each copy of the Program.

Contributors may not remove or alter any copyright notices contained
within the Program.

Each Contributor must identify itself as the originator of its
Contribution, if any, in a manner that reasonably allows subsequent
Recipients to identify the originator of the Contribution.

*4. COMMERCIAL DISTRIBUTION*

Commercial distributors of software may accept certain responsibilities
with respect to end users, business partners and the like. While this
license is intended to facilitate the commercial use of the Program, the
Contributor who includes the Program in a commercial product offering
should do so in a manner which does not create potential liability for
other Contributors. Therefore, if a Contributor includes the Program in
a commercial product offering, such Contributor ("Commercial
Contributor") hereby agrees to defend and indemnify every other
Contributor ("Indemnified Contributor") against any losses, damages and
costs (collectively "Losses") arising from claims, lawsuits and other
legal actions brought by a third party against the Indemnified
Contributor to the extent caused by the acts or omissions of such
Commercial Contributor in connection with its distribution of the
Program in a commercial product offering. The obligations in this
section do not apply to any claims or Losses relating to any actual or
alleged intellectual property infringement. In order to qualify, an
Indemnified Contributor must: a) promptly notify the Commercial
Contributor in writing of such claim, and b) allow the Commercial
Contributor to control, and cooperate with the Commercial Contributor
in, the defense and any related settlement negotiations. The Indemnified
Contributor may participate in any such claim at its own expense.

For example, a Contributor might include the Program in a commercial
product offering, Product X. That Contributor is then a Commercial
Contributor. If that Commercial Contributor then makes performance
claims, or offers warranties related to Product X, those performance
claims and warranties are such Commercial Contributor's responsibility
alone. Under this section, the Commercial Contributor would have to
defend claims against the other Contributors related to those
performance claims and warranties, and if a court requires any other
Contributor to pay any damages as a result, the Commercial Contributor
must pay those damages.

*5. NO WARRANTY*

EXCEPT AS EXPRESSLY SET FORTH IN THIS AGREEMENT, THE PROGRAM IS PROVIDED
ON AN "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES
OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR
A PARTICULAR PURPOSE. Each Recipient is solely responsible for
determining the appropriateness of using and distributing the Program
and assumes all risks associated with its exercise of rights under this
Agreement , including but not limited to the risks and costs of program
errors, compliance with applicable laws, damage to or loss of data,
programs or equipment, and unavailability or interruption of operations.

*6. DISCLAIMER OF LIABILITY*

EXCEPT AS EXPRESSLY SET FORTH IN THIS AGREEMENT, NEITHER RECIPIENT NOR
ANY CONTRIBUTORS SHALL HAVE ANY LIABILITY FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING
WITHOUT LIMITATION LOST PROFITS), HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OR
DISTRIBUTION OF THE PROGRAM OR THE EXERCISE OF ANY RIGHTS GRANTED
HEREUNDER, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

*7. GENERAL*

If any provision of this Agreement is invalid or unenforceable under
applicable law, it shall not affect the validity or enforceability of
the remainder of the terms of this Agreement, and without further action
by the parties hereto, such provision shall be reformed to the minimum
extent necessary to make such provision valid and enforceable.

If Recipient institutes patent litigation against any entity (including
a cross-claim or counterclaim in a lawsuit) alleging that the Program
itself (excluding combinations of the Program with other software or
hardware) infringes such Recipient's patent(s), then such Recipient's
rights granted under Section 2(b) shall terminate as of the date such
litigation is filed.

All Recipient's rights under this Agreement shall terminate if it fails
to comply with any of the material terms or conditions of this Agreement
and does not cure such failure in a reasonable period of time after
becoming aware of such noncompliance. If all Recipient's rights under
this Agreement terminate, Recipient agrees to cease use and distribution
of the Program as soon as reasonably practicable. However, Recipient's
obligations under this Agreement and any licenses granted by Recipient
relating to the Program shall continue and survive.

Everyone is permitted to copy and distribute copies of this Agreement,
but in order to avoid inconsistency the Agreement is copyrighted and may
only be modified in the following manner. The Agreement Steward reserves
the right to publish new versions (including revisions) of this
Agreement from time to time. No one other than the Agreement Steward has
the right to modify this Agreement. The Eclipse Foundation is the
initial Agreement Steward. The Eclipse Foundation may assign the
responsibility to serve as the Agreement Steward to a suitable separate
entity. Each new version of the Agreement will be given a distinguishing
version number. The Program (including Contributions) may always be
distributed subject to the version of the Agreement under which it was
received. In addition, after a new version of the Agreement is
published, Contributor may elect to distribute the Program (including
its Contributions) under the new version. Except as expressly stated in
Sections 2(a) and 2(b) above, Recipient receives no rights or licenses
to the intellectual property of any Contributor under this Agreement,
whether expressly, by implication, estoppel or otherwise. All rights in
the Program not expressly granted under this Agreement are reserved.

This Agreement is governed by the laws of the State of New York and the
intellectual property laws of the United States of America. No party to
this Agreement will bring a legal action under this Agreement more than
one year after the cause of action arose. Each party waives its rights
to a jury trial in any resulting litigation.

