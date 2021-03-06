require 'savon'
require 'date'
require 'time'
require 'gyoku'

######################################################################################################################
## Version:: 0.1
## Tested with:: FMG/FAZ 5.0.7
## Tested with:: Ruby 1.9.3 and Ruby 2.0.0
## Author:: Nick Petersen (2014)
## License:: Distributes under the same terms as Ruby
######################################################################################################################
## Summary::
## Provides simplified interaction with the Fortinet FortiManager/FortiAnalyzer XML API.  Class methods
## are implemented to abstract the complexity in executing FMG XML API queries via Ruby.
##
## Uses Savon Gem for SOAP query/response handling.  Most Savon initialization parameters are pre-set with values that
## are known to work with FortiManager and FortiAnalyzer.
##
## +Usage:+
##  fmg1 = FmgApi.new('wsdl_file_location', 'url', 'namespace', 'userid', 'passwd')
##  result = fmg1.get_adom_list
##
## WSDL file should be locally accessible by the class
## Namespace for FMG/FAZ to this point has been:  http://r200806.ws.fmg.fortinet.com/
## URL generally is https://<fmg/faz_ip>:8080  (web service should be enabled on FMG/FAZ)
##
##
## +Important:+ Arguments to fmgapi methods are passed in as hash key => value instead of traditional
## arguments passed in order.   This is because many methods have several optional arguments and in some cases required
## arguments can be left out if other required arguments are used.
##
## When specifying hash key/value arguments to a method, use the following syntax:
##
## Single argument passed:
##  method_name(argument_key => 'argument_value')
## Multiple arguments passed:
##  method_name({argument1_key => 'argument1_value', argument2_key => 'agrument2_value'})
######################################################################################################################

class FmgApi
  def initialize(wsdl, endpoint, namespace, userid, passwd)
    @wsdl = wsdl
    @endpoint = endpoint
    @namespace = namespace
    @userid = userid
    @passwd = passwd

    #create a savon client for the service
    @client = Savon.client(
        wsdl: @wsdl,
        endpoint: @endpoint,   #used if you don't have wsdl  (or possibly if only have local wsdl file?)
        namespace: @namespace,   #used if you don't have wsdl
        ##
        ############ SSL Attributes ##########
        ssl_verify_mode: :none,        # verify or not SSL Certificate
        # ssl_version: :SSLv3,          # or one of [:TLSv1, :SSLv2]
        # ssl_cert_file:  "path/client_cert.pem",
        # ssl_cert_key_file: "path/client_key.pem",
        # ssl_cert_key_file:  "path/ca_cert.pem",        #CA certificate file to use
        # ssl_cert_key_password: "secret",
        ##
        ############ SOAP Protocol Attributes
        ##
        # soap_header: { "token" => "secret" }, #if you need to add customer XML to the SOAP header.  useful for auth token?
        # soap_version: 2,       #defaults to SOAP 1.1
        ##
        ############ MISC Attributes
        ##
        pretty_print_xml: true,        # print the request and response XML in logs in pretty
    # headers: {"Authentication" => "secret", "etc" => "etc"},
     #open_timeout: 5,           # in seconds
     #read_timeout: 5,           # in seconds
    ##
    ########## LOGGING Attributes ##############
    ##
    # log: false,
    # logger: rails.logger,  #by default will log to $stdout (ruby's default logger)
    # log_level: :info,  #one of [:debug, :info, :warn, :error, :fatal]
    # filters: [:password],  #sensitive info can be filtered from logs.  specifies which arguments to filter from logs
    ##
    ########### RESPONSE Attributes ##############
    ##
    # strip_namespace: false    # default is to strip namespace identifiers from the response
    # convert_response_tags_to: upcase  # value is name of a proc that takes an action you've created
    )
    @authmsg = {:servicePass => {:userID => @userid, :password => @passwd}}
  end

  ################################################################################################
  ## add_adom Returns Hash (with FMG error_code and error_msg, when successful) or Error (if not successful)
  ##
  ## Adds an ADOM to FortiManager or FortiAnalyzer.
  ##
  ## Takes up to 2 arguments of types 1=hash, 2=(hash or array of hashes or false)
  ##
  ## +Argument_1:+ is of type Hash with following required (R) and optional (O)
  ##  (R) :name               # Name of ADOM to edit
  ##  (O) :is_backup_mode     # 0=no, 1=yes, default=no
  ##  (O) :version            # Version to set   (example: '500')
  ##  (O) :mr                 # Major Release Version to set   (example '0')
  ##
  ## +Argument_2:+ is optional and is of type Hash (for single device entry) or type Array of Hashes (for multiple device entries)
  ## Specifies devices/vdoms to add to this ADOM.  If you need to pass the 3rd argument for meta data but not pass any devices
  ## then you should just put false in the place of this argument.
  ## Hash or Hashes must be specified with one of the following parameter combinations:
  ##  {:serial_number => 'serial-num', :vdom_name => 'vdom-name'}
  ##  {:serial_number => 'serial-num', :vdom_id => 'vdom-id'}
  ##  {:dev_id => 'device-id', :vdom_name => 'vdom-name'}
  ##  {:dev_id => 'device-id', :vdom_id => 'vdom-id'}
  ##
  ##
  ## +Example1:+ (add a new ADOM)
  ##  add_adom({:name => 'adomA'})
  ##
  ## +Example2:+ (add ADOM and assign single VDOM to the new ADOM)
  ##  add_adom({:name => 'adomA'}, {:serial_number => 'FGVM11111111', :vdom_name => 'vdomA'})
  ##
  ## +Example3:+ (add new ADOM and assign multiple VDOMs to the ADOM)
  ##  newdevices = Array.new
  ##  newdevices[0] = {:serial_number => 'FGVM11111111', :vdom_name => 'vdomA'}
  ##  newdevices[1] = {:serial_number => 'FGVM11111111', :vdom_name => 'vdomB'}
  ##  newdevices[2] = {:serial_number' => 'FGVM22222222, :vdom_name => 'vdomC'}
  ##  newdevices[3] = {:dev_id => '234', :vdom_name => 'vdomD'}
  ##  newdevices[4] = {:dev_id => '234', :vdom_id => '2178'}
  ##  add_adom({:name => 'adomA'}, newdevices)
  ################################################################################################
  def add_adom(opts = {}, devices=false)
    querymsg = @authmsg
    querymsg[:is_backup_mode] = opts[:is_backup_mode] ? opts[:is_backup_mode] : '0'
    #querymsg[:VPN_management] = opts[:vpn_management] ? opts[:vpn_management] : '0'

    begin
      if opts[:name]
        querymsg[:name] = opts[:name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name')
      end

      ## If the optional :mr argument is passed, for safety we require that :version is also passed.  If neither is set
      ## we will default it as it is required parameter.
      if opts[:mr] && opts[:version]
        querymsg[:version] = opts[:version]
        querymsg[:mr] = opts[:mr]
      elsif opts[:version] && !opts[:mr]
        raise ArgumentError.new('If you specify :version you must also specify :mr')
      elsif opts[:mr] && !opts[:version]
        raise ArgumentError.new('If you specify :mr you must also specify :version')
      else
        querymsg[:version] = '500'
        querymsg[:mr] = '0'
      end

      # Check if the target devices was passed in.  If so add the target devices tags to the query.
      if devices.is_a?(Array)
        ## If multiple devices are passed in through the array then we may have duplicate tags that need to be added
        ## to the query.  Hashes cannot handle duplicate tags (aka keys) so we must convert to a string of xml and add
        ## the parameters to the string as xml attributes instead.
        querymsgxml = Gyoku.xml(querymsg)
        devices.each { |x|
          if (x[:serial_number] || x[:dev_id]) && (x[:vdom_name] || x[:vdom_id])
            querymsgxml += '<deviceSNVdom>' + Gyoku.xml(x) if x[:serial_number]
            querymsgxml += '<deviceIDVdom>' + Gyoku.xml(x) if x[:dev_id] && !x[:serial_number]

            # The FMG API +sometimes+ capitalizes not just the letters between words (addDeviceIdVdom) but instead requires
            # in +some+ instances that two or more letters sequentially be capitalized (addDeviceIDVDom).  Normal camel case
            # processing usually takes care of this for us in instances where just first letter after an _ should be capital
            # but we don't want to force capitalizing only one or two letters in any otherwise lowercase :symbol so we adjust
            # the casing here using gsub
            querymsgxml = querymsgxml.gsub(/deviceIdVdom/, 'deviceIDVdom')
            querymsgxml = querymsgxml.gsub(/deviceSnVdom/, 'deviceSNVdom')
            querymsgxml = querymsgxml.gsub(/serialNumber/, 'SN')
            querymsgxml = querymsgxml.gsub(/devId/, 'ID')
            querymsgxml = querymsgxml.gsub(/vdomId/, 'vdomID')

            querymsgxml += '</deviceSNVdom>' if x[:serial_number]
            querymsgxml += '</deviceIDVdom>' if x[:dev_id] && !x[:serial_number]
          else
            raise ArgumentError.new('Must provide required arguments within the \"devices\" Array/Hash argument-> the 2nd argument (for devices to add) must contain (:serial_number or :dev_id) AND (:vdom_name or :vdom_id')
          end
        }
      elsif devices.is_a?(Hash)
        if devices[:serial_number] && devices[:vdom_name]
          querymsg[:device_sN_vdom] = {}
          querymsg[:device_sN_vdom][:serial_number] = devices[:serial_number]
          querymsg[:device_sN_vdom][:vdom_name] = devices[:vdom_name]
        elsif devices[:serial_number] && devices[:vdom_id]
          querymsg[:device_sN_vdom] = {}
          querymsg[:device_sN_vdom][:serial_number] = devices[:serial_number]
          querymsg[:device_sN_vdom][:vdom_id] = devices[:vdom_id]
        elsif devices[:dev_id] && devices[:vdom_name]
          querymsg[:device_iD_vdom] = {}
          querymsg[:device_iD_vdom][:iD] = devices[:dev_id]
          querymsg[:device_iD_vdom][:vdom_name] = devices[:vdom_name]
        elsif devices[:dev_id] && devices[:vdom_id]
          querymsg[:device_iD_vdom] = {}
          querymsg[:device_iD_vdom][:serial_number] = devices[:dev_id]
          querymsg[:device_iD_vdom][:vdom_id] = devices[:vdom_id]
        else
          raise ArgumentError.new('Must provide required arguments for method-> the 2nd argument (for devices to add) to add must contain :serial_number & (:vdom_name or :vdom_id')
        end
      end

      if querymsgxml
        exec_soap_query(:add_adom,querymsgxml,:add_adom_response,:error_msg)
      else
        exec_soap_query(:add_adom,querymsg,:add_adom_response,:error_msg)
      end
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## add_device Returns String (string contains taskID of addDevice task, you can lookup the task to get results)
  ## NOTE: may take several minutes for the fmg to import the device
  ##
  ## Causes FortiManager/FortiAnalyzer to communicate with specified Fortinet device (specified by IP) to import
  ## as a managed device into the FMG/FAZ.  This has only been tested for adding FortiGate devices.
  ##
  ## +Usage:+
  ##  add_device({:ip => 'x.x.x.x', :name => 'name-to-give'})
  ##
  ## +Optional_Arguments:+
  ##  :adom         # defaults to root if not provided
  ##  :admin_user   # defaults to admin if not provided
  ##  :password     # defaults to '' if not provided
  ##  :description  # not set if not provided
  ##
  #--
  ## Arguments available by FMG/FAZ API but not yet implemented in this class#method  (Do not attempt to use these!)
  ## :version
  ## :mr
  ## :autod
  ## :model
  ## :flags
  ## :dev_id
  ## :serial_number
  #++
  ################################################################################################
  def add_device(opts = {})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:admin_user] = opts[:admin_user] ? opts[:admin_user] : 'admin'
    querymsg[:password] = opts[:password] ? opts[:password] : ''
    querymsg[:description] = opts[:description] if opts[:description]

    begin
      if opts[:ip] && opts[:name]
        querymsg[:ip] = opts[:ip]
        querymsg[:name] = opts[:name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :ip and :name')
      end
      exec_soap_query(:add_device,querymsg,:add_device_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## add_group Returns Hash with API error hash (if successful) or returns Object Type Error likely a RunTimeError (if
  ## not successful)  Hash returned if successful includes keys error_code and error_message.
  ##
  ## Adds a new group to FMG/FAZ.  Optionally can add one device to that new group as well.  If more than one devices
  ## needs to be added to the group or you need to add the devices later, use the edit_group_membership method.
  ##
  ## +Usage:+
  ##  add_group({:name => 'new-group-name'})
  ##
  ## +Optional_Arguments:+
  ##  :adom         # defaults to root if not provided
  ##  :description  # not set if not provided
  ##  :device_sn    # serial number of a single device to add to this new group (pass :device_sn or :device_id or neither)
  ##  :device_id    # device id of single device to add to this new group (pass :device_sn or :device_id or neither)
  ##  # Note: multiple groups can contain the same device(s)
  #--
  ##  :group_name   # specifies name of an existing group to include as a member in this new group
  ##  :group_id     # specifies ID of an existing group to include as a member in this new groupt
  #++
  ################################################################################################
  def add_group(opts = {})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:description] = opts[:description] if opts[:description]
    querymsg[:group_name] = opts[:group_name] if opts[:group_name]

    if opts[:device_sn]
      querymsg[:device_sN] = opts[:device_sn]
    elsif opts[:device_id]
      querymsg[:device_iD] = opts[:device_id]
    end

    begin
      if opts[:name]
        querymsg[:name] = opts[:name]
       else
        raise ArgumentError.new('Must provide required arguments for method-> :group_name')
      end
      exec_soap_query(:add_group,querymsg,:add_group_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## add_policy_package Returns NoriStringWithAttributes (string contains OID of package that operation was successfully
  ## completed on)
  ##
  ## Multiple operations possible.  Create new FMG policy package, including adding installation targets. Also may
  ## clone an existing policy package, rename an existing policy package or add installation targets to an existing
  ## policy package.
  ##
  ## +Usage:+
  ##  add_policy_package({:policy_package_name => 'new-pkg-name'}) OR
  ##  add_policy_package({:policy_package_name => 'new-pkf-name'}, *ArrayOfHashes)
  ##   Optional *ArrayOfHashes 2nd argument contains install target definitions.  See Optional_Arguments(ARG2-ArrayOfHashes) below:
  ##
  ## Optional_Arguments(ARG1-Hash):
  ##  :adom                  # defaults to root if not passed
  ##  :is_global             # 0=create local package, 1=create global package.  defaults to 0.  If set to 1, ignores the :adom setting and assigns in global ADOM
  ##  :fg_is_not_vdom_mode  # 0=all fortigates referenced are in vdom mode, 1 = one or more of FGs is not in vdom mode
  ##                        # default is 0.  This is a protection mechanism in this method to "help" prevent adding a "device" to a policy package
  ##                        # instead of a vdom to a policy package as the FMG will let you do this.   In order to add a "device" to an install
  ##                        # target instead of a vdom to an install target you must set this to 1.  However, if you do set this to one, if you
  ##                        # are adding multiple devices in this single call then it will not prevent adding "devices" vs. "vdoms" to policy package
  ##                        # for any of the devices referenced in this call. Even if the some fgs are in vdom mode.
  ##  :rename                # rename :policy_package_name to :rename  (not set if not passed)
  ##  :clone_from            # when creating a new :policy_package_name you can clone from an existing (in same ADOM) with name specified in :clone_from
  ##
  ## Optional_Arguments(ARG2-ArrayOfHashes)  (This may be a single hash for one install target or array of hashes for multiple)
  ##
  ## Example-1:  (adding multiple vdoms via ArrayOfHashes to package install targets)
  ##  myinstalltargets = Array.new
  ##  myinstalltargets[0] = {:dev => {:name => 'MSSP-1', :vdom => {:name => 'root'}}}
  ##  myinstalltargets[1] = {:dev => {:name => 'MSSP-1', :vdom => {:name => 'transparent'}}
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, myinstalltargets})
  ## Example-2:  (adding single vdom via Hash to package install targets)
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:dev => {:name => 'MSSP-1', :vdom =>{:name => 'root'}}) OR
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:dev => {:name => 'MSSP-1', :vdom =>{:oid => '3'}}} OR
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:dev => {:oid => '123', :vdom => {:name => 'root'}}) OR
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:dev => {:oid => '123', :vdom => {:oid => '3'}})
  ##  add_policy_package({:policy_package_name => 'pkg-name', :fg_is_not_vdom_mode => '1'}), {:dev => {:name => 'MSSP-1'})
  ##  add_policy_package({:policy_package_name => 'pkg-name', :fg_is_not_vdom_mode => '1'}), {:dev => {:oid => '123'})
  ## Example-3: (adding a group to package install targets)
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:grp => {:name => 'grp-name'}) OR
  ##  add_policy_package({:policy_package_name => 'pkg-name'}, {:grp => {:oid => 'grp-oid'})
  ################################################################################################
  def add_policy_package(opts = {}, install_targets=false)
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:is_global] = opts[:is_global] ? opts[:is_global] : '1'
    querymsg[:clone_from] = opts[:clone_from] if opts[:clone_from]
    querymsg[:rename] = opts[:rename] if opts[:rename]

    begin
      if opts[:policy_package_name]
        querymsg[:policy_package_name] = opts[:policy_package_name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :policy_package_name')
      end
      # Because we need multiple attributes of same name contained in query message to specify more than one target we
      # cannot using hash as container to pass to Savon.  We instead must convert existing hash to xml string and append
      # the repetitious attributes.  Hash to XML translation is done with Gyoku.xml() method.
      if install_targets.is_a?(Array)
        querymsgxml = Gyoku.xml(querymsg) + '<packageInstallTarget>'
        install_targets.each { |x|
          if x[:grp]
            if x[:grp][:oid] || x[:grp][:name]
              querymsgxml += Gyoku.xml(x)
            else
              raise ArgumentError.new('Install target was passed with hash key :grp but did not contain one of sub keys :oid or :name')
            end
          elsif x[:dev]
            if x[:dev][:oid] || x[:dev][:name]
              if x[:dev][:vdom]
                if !x[:dev][:vdom][:oid] && !x[:dev][:vdom][:name]
                  raise ArgumentError.new('Install target was passed with hash key :dev and sub key :vdom but :vdom did not contain one of subkeys :oid or :name')
                end
              end
              if x[:dev][:vdom] || opts[:fg_is_not_vdom_mode] == '1'
                querymsgxml += Gyoku.xml(x)
              else
                raise ArgumentError.new('One or more targets is a device and not a vdom while :fg_is_not_vdom_mode was not set to 1')
              end
            else
              raise ArgumentError.new('At least one of targets were passed with top key :dev but did not have one of required sub-keys :oid, :name or :vdom')
            end
          else
            raise ArgumentError.new('Install target was passed but at least one of target hashes did not have one of top-level keys, either :grp or :dev')
          end
        }
        querymsgxml += '</packageInstallTarget>'
      elsif install_targets.is_a?(Hash)
        querymsgxml = Gyoku.xml(querymsg) + '<packageInstallTarget>'
        if install_targets[:grp]
          if install_targets[:grp][:oid] || install_targets[:grp][:name]
            querymsgxml += Gyoku.xml(install_targets)
          else
            raise ArgumentError.new('Install target was passed with hash key :grp but did not contain one of sub keys :oid or :name')
          end
        querymsgxml += '</packageInstallTarget>'
        elsif install_targets[:dev]
          if install_targets[:dev][:oid] || install_targets[:dev][:name] || install_targets[:dev][:vdom]
            if install_targets[:dev][:vdom]
              if !install_targets[:dev][:vdom][:oid] && !install_targets[:dev][:vdom][:name]
                raise ArgumentError.new('Install target was passed with hash key :dev and sub key :vdom but :vdom did not contain one of subkeys :oid or :name')
              else
                querymsgxml += Gyoku.xml(install_targets)
              end
            else
              if x[:dev][:vdom] || opts[:fg_is_not_vdom_mode] == '1'
                querymsgxml += Gyoku.xml(install_targets)
              else
                raise ArgumentError.new('One or more targets is a device and not a vdom while :fg_is_not_vdom_mode was not set to 1')
              end
            end
          else
            raise ArgumentError.new('At least one of targets were passed with top key :dev but did not have one of required sub-keys :oid, :name or :vdom')
          end
        end
      end

      if querymsgxml
        exec_soap_query(:add_policy_package,querymsgxml,:add_policy_package_response,:policy_package_oid)
      else
        exec_soap_query(:add_policy_package,querymsg,:add_policy_package_response,:policy_package_oid)
      end
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end
  alias :edit_policy_package :add_policy_package

  ################################################################################################
  ## assign_global_policy Returns Nori::StringWithAttributes (string contains task ID of process)
  ##
  ## Assigns a global policy package to ADOMs or specific packages inside of ADOM.  (Note: specific package assignment does
  ## not seem to be working as of 5.0.7.  Additionally, Assignment doesn't show up under the global package assignments tab
  ## even when successful, although you will see the global rules in the target packages themselves.)
  ##
  ## +Usage:+
  ##  assign_global_policy({}:policy_package_name}, *hash-or-array-of-hashses)
  ##
  ## :policy_package_name is name of global policy package to assign
  ## *hash-or-array-of-hashes defines the target ADOM and packages and contains the following parameter syntax per hash
  ## {:name => 'target-adom-name', pkg => {:oid => 'oid-of-target-packages-in-adom'}}
  ##
  ## +Optional-Arguments:+
  ##  :all_objects  # Add all global package objects to local policy regardless of use in policy? 0=no, 1=yes, default=no
  ##  :install_to_device # Install to device after package assignment: 0=no, 1=yes, default=no
  ##  :check_assignd_dup # Check for duplicate global policy assignments:  0=no, 1=yes, default=no
  ##
  ## Example1: (with single adom/package targets passed as Hash)
  ##  assign_global_policy(:policy_package_name => 'global-policy-1'}, {:name => 'adomA', :pkg => {:oid => '602'}})
  ##
  ## Example2:(with multiple adom/package targets passed as Array of Hashes)
  ##  mytargetpkgs = Array.new
  ##  mytargetpkgs[0] = {:name => 'adomA', :pkg => {:oid => '602'}}
  ##  mytargetpkgs[1] = {:name => 'adomA', :pkg => {:oid => '603'}}
  ##  mytargetpkgs[0] = {:name => 'adomB', :pkg => {:oid => '703'}}
  ##  assign_global_policy({:policy_package_name => 'global-policy-1'}, mytargetpkgs)
  ##
  ## Example3: (with singe adom/package targets passed as hash and optional arguments)
  ##  assign_global_policy(:policy_package_name => 'global-policy-1', :all_objects => '1', :install_to_device => '1'}, {:name => 'adomA', :pkg => {:oid => '602'}})
  ################################################################################################
  def assign_global_policy(opts = {}, targets=false)
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'Global'
    querymsg[:policy_package_name] =  opts[:policy_package_name] ? opts[:policy_package_name] : 'default'
    querymsg[:all_objects] = opts[:all_objects] ? opts[:all_objects] : '0'
    querymsg[:install_to_device] = opts[:install_to_device] ? opts[:install_to_device] : '0'
    querymsg[:check_assignd_dup] = opts[:check_assignd_dup] ? opts[:check_assignd_dup] : '0'

    begin
      ## If we have more than one target, that will require multiple copies of identical tags which cannot be handled
      ## when using Hash format for passing parameters to Savon.  So we instead convert to an XML based string first
      ## then append our multiple entries to the string as XML.
      if targets.is_a?(Array)
        querymsgxml = Gyoku.xml(querymsg)
        targets.each { |x|
          if x[:name] && x[:pkg][:oid]
            querymsgxml += '<adomList>' + Gyoku.xml(x) + '</adomList>'
          else
            raise ArgumentError.new('Target(s) array of hashes did not include elements :name and one of (:pkg->:oid or :pkg->:name)')
          end
        }
      elsif targets.is_a?(Hash)
          if targets[:name] && targets[:pkg][:oid]
            querymsg[:adom_list] = {}
            querymsg[:adom_list][:name] = targets[:name]
            querymsg[:adom_list][:pkg] = {}
            querymsg[:adom_list][:pkg][:oid] = targets[:pkg][:oid]
          else
            raise ArgumentError.new('Target(s) hash did not include elements :name and one of (:pkg->:oid or :pkg->:name)')
          end
      else
        raise ArgumentError.new('Target package(s) detail must be passed as a Hash (for single target) or Array of Hashes (for multiple targets')
      end

      if querymsgxml
        exec_soap_query(:assign_global_policy,querymsgxml,:assign_global_policy_response,:task_id)
      else
        exec_soap_query(:assign_global_policy,querymsg,:assign_global_policy_response,:task_id)
      end

    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## create_script Returns Nori::StringWithAttributes (string contains 0 for success or 1 for failed)
  ##
  ## Creates a new script in the designated ADOM
  ##
  ## +Usage:+
  ## create_script({:adom => 'adom-to-create-in, :name => 'name-of-script-to-create', :content => 'content-of-script-to-create'})
  ##
  ## +Optional_Arguments:+
  ##  :type         # type of script options are CLI or TCL.  default=CLI
  ##  :description  # description of script.   default='created via XML API'
  ##  :overwrite    # if script name already exists overwrite?  0=no, 1=yes, default=no
  ##  :is_global    # create this as a global script. 0=no, 1=yes, default=no.
  #################################################################################################
  def create_script(opts = {})
    querymsg = @authmsg
    querymsg[:is_global] = opts[:is_global] ? opts[:is_global] : '0'
    querymsg[:type] = opts[:type] ? opts[:type] : 'CLI'
    querymsg[:description] = opts[:description] ? opts[:description] : 'created via XML API'
    querymsg[:overwrite] = opts[:overwrite] ? opts[:overwrite] : '0'

    begin
      if opts[:adom] && opts[:name] && opts[:content]
        querymsg[:adom] =  opts[:adom]
        querymsg[:name] = opts[:name]
        querymsg[:content] = opts[:content]
      else
        raise ArgumentError.new('Must provide required arguments for method -> :adom, :name and :content')
      end
      exec_soap_query(:create_script,querymsg,:create_script_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## delete_adom Returns Hash (if hash is return object then it was executed successfully)
  ##
  ## Deletes specified ADOM
  ##
  ## +Usage:+
  ##  delete_adom(:adom_name => 'adom-name') OR
  ##  delete_adom(:adom_oid => 'adom-oid')
  ################################################################################################
  def delete_adom(opts = {})
    querymsg = @authmsg

    begin
      if opts[:adom_name]
        querymsg[:adom_name] = opts[:adom_name]
      elsif opts[:adom_oid]
        querymsg[:adom_oid] = opts[:adom_oid]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :adom_name OR adom_oid')
      end
      exec_soap_query(:delete_adom,querymsg,:delete_adom_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## delete_config_rev Returns Hash (if hash is return object then it was executed successfully)
  ##
  ## Deletes specified configuration revision
  ## +Usage:+
  ##  delete_config_rev({:serial_number => 'serial-number', :rev_name => 'revision-name'}) OR
  ##  delete_config_rev({:serial_number => 'serial-number', :rev_id => 'revision-id'}) OR
  ##  delete_config_rev({:dev_id => 'device-id', :rev_name => 'revision-name'}) OR
  ##  delete_config_rev{{dev_id => 'device-id', :rev_id => 'revision-id'}}
  ################################################################################################
  def delete_config_rev(opts = {})
    querymsg = @authmsg

    begin
      if opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      elsif opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :serial_number or :dev_id  (in addition to :rev_name or :rev_id')
      end
      if opts[:rev_name]
        querymsg[:rev_name] = opts[:rev_name]
      elsif opts[:rev_id]
        querymsg[:rev_id] = opts[:rev_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :rev_name or :rev_id (in addition to :serial_number or :dev_id')
      end
      exec_soap_query(:delete_config_rev,querymsg,:delete_config_rev_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## delete_device Nori::StringWithAttributes (string contains taskID of fmg delete device process. Must get results from task)
  ##
  ## Deletes specified device
  ## +Usage:+
  ##  delete_device({:serial_number => 'serial-number'}) OR
  ##  delete_device({:dev_id => 'device-id'})
  ################################################################################################
  def delete_device(opts = {})
    querymsg = @authmsg

    begin
      if opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      elsif opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :serial_number or :dev_id')
      end
      exec_soap_query(:delete_device,querymsg,:delete_device_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## delete_group Returns Hash (if object type of Hash is returned then executed successfully)
  ##
  ## Deletes specified group
  ## +Usage:+
  ##  delete_group({:grp_name => 'group-name', :adom=> 'adom-name'}) OR
  ##  delete_group({:grp_id => 'group-id', :adom => 'adom-name'})
  ################################################################################################
  def delete_group(opts = {})
    querymsg = @authmsg

    begin
      if opts[:grp_name] && opts[:adom]
        querymsg[:name] = opts[:grp_name]
        querymsg[:adom] = opts[:adom]
      elsif opts[:grp_id] && opts[:adom]
        querymsg[:grp_id] = opts[:grp_id]
        querymsg[:adom] = opts[:adom]
      else
        raise ArgumentError.new('Must provide required arguments for method-> (:grp_name or :grp_id) and :adom')
      end
      exec_soap_query(:delete_group,querymsg,:delete_group_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## delete_script
  ##
  ## Deletes specified script
  ##
  ## +Usage:+
  ##  delete_script({:name => 'name-of-script'})
  ##
  ## +Optional_Arugments:+
  ##  :type  #type of script.  CLI or TCL.  defaults to CLI
  ################################################################################################
  def delete_script(opts = {})
    querymsg = @authmsg
    querymsg[:type] = opts[:type] ? opts[:type] : 'CLI'

    begin
      if opts[:name]
        querymsg[:name] = opts[:name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name')
      end
      exec_soap_query(:delete_script,querymsg,:delete_script_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## edit_adom Returns Hash (with FMG error_code and error_msg when successful) or RunTimeError (if not successful)
  ##
  ## Edits specified ADOM.  Provides ability to change:  backup mode, vpn management, version, devices/adoms, or metadata
  ##
  ## Takes up to 3 arguments of types 1=hash, 2=(hash or array of hashes or false), 3=(hash or array of hashes)
  ## +Argument_1:+ is of type Hash with following required (R) and optional (O)
  ##  (R) :name               # Name of ADOM to edit
  ##  (O) :is_backup_mode     # 0=no, 1=yes, default=no
  ##  (O) :version            # Version to set   (example: '500')
  ##  (O) :mr                 # Major Release Version to set   (example '0')
  ##
  ## +Argument_2:+ is optional and is of type Hash (for single device entry) or type Array of Hashes (for multiple device entries)
  ##
  ## Specifies devices/vdoms to add to this ADOM.  If you need to pass the 3rd argument for meta data but not pass any devices
  ## then you should just put false in the place of this argument.
  ## Hash or Hashes must be specified with one of the following parameter combinations:
  ##  {:serial_number => 'serial-num', :vdom_name => 'vdom-name'}
  ##  {:serial_number => 'serial-num', :vdom_id => 'vdom-id'}
  ##  {:dev_id => 'device-id', :vdom_name => 'vdom-name'}
  ##  {:dev_id => 'device-id', :vdom_id => 'vdom-id'}
  ##
  ## +Argument_3:+ is optional and is of type Hash (for single meta value entry) or as an Array of Hashes (for multiple meta entries)
  ## Specifies meta data tags to edit on the ADOM. Hash(es) should be of the following format:
  ##  {:name => 'meta-tag-name', :value => 'meta-tag-value'}
  ##
  ## +Example1:+ (change the backup mode to backup-mode)
  ##  edit_adom({:name => 'adomA', :is_backup_mode => '1'}
  ##
  ## +Example2:+ (add a single vdom)
  ##  edit_adom({:name => 'adomA'}, {:serial_number => 'FGVM11111111', :vdom_name => 'vdomA'})
  ##
  ## +Example3:+ (add multiple vdoms)
  ##  newdevices = Array.new
  ##  newdevices[0] = {:serial_number => 'FGVM11111111', :vdom_name => 'vdomA'}
  ##  newdevices[1] = {:serial_number => 'FGVM11111111', :vdom_name => 'vdomB'}
  ##  newdevices[2] = {:serial_number' => 'FGVM22222222, :vdom_name => 'vdomC'}
  ##  newdevices[3] = {:dev_id => '234', :vdom_name => 'vdomD'}
  ##  newdevices[4] = {:dev_id => '234', :vdom_id => '2178'}
  ##  edit_adom({:name => 'adomA'}, newdevices)
  ##
  ## +Example4:+ (edit meta data but add no vdoms)
  ##  newmetadata = Array.new
  ##  newmetadata[0] = {:name => 'meta1', :value => 'value1'}
  ##  newmetadata[1] = {:name => 'meta2', :value => 'value2'}
  ##  edit_adom({:name => 'adomA'}, false, newmetadata)
  ##
  ## +Example5:+ (add single device/vdom and single meta data entry)
  ##  edit_adom({:name => 'adomA'}, {:serial_number => 'FGVM11111111', :vdom_name => 'vdomA'}, {:name => 'meta1', value => 'value1'})
  ################################################################################################
  def edit_adom(opts = {}, devices=false, meta=false)
    querymsg = @authmsg
    querymsg[:is_backup_mode] = opts[:is_backup_mode] if opts[:is_backup_mode]
    querymsg[:state] = opts[:state] if opts[:state]
    querymsg[:vpn_management] = opts[:vpn_management] if opts[:vpn_management]

    begin
      if opts[:name]
        querymsg[:name] = opts[:name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name')
      end

      ## If the optional :mr argument is passed, for safety we require that :version is also passed.
      if opts[:mr] && opts[:version]
        querymsg[:version] = opts[:version] if opts[:version]
        querymsg[:mr] = opts[:mr] if opts[:mr]
      elsif opts[:mr] && !opts[:version]
        raise ArgumentError.new('Argument error: provided :mr but not :version')
      elsif opts[:version] && !opts[:mr]
        raise ArgumentError.new('Argument error: provided :version but not :mr')
      end

      # Check if the target devices was passed in.  If so add the target devices tags to the query.s
      if devices.is_a?(Array)
        ## If multiple devices are passed in through the array then we may have duplicate tags that need to be added
        ## to the query.  Hashes cannont handle duplicate tags (aka keys) so we must convert to a string of xml and add
        ## the parameters to the string as xml attributes instead.
        querymsgxml = Gyoku.xml(querymsg)
        devices.each { |x|
        if (x[:serial_number] || x[:dev_id]) && (x[:vdom_name] || x[:vdom_id])
          querymsgxml += '<addDeviceSNVdom>' + Gyoku.xml(x) if x[:serial_number]
          querymsgxml += '<addDeviceIDVdom>' + Gyoku.xml(x) if x[:dev_id] && !x[:serial_number]

          # The FMG API +sometimes+ capitalizes not just the letters between words (addDeviceIdVdom) but instead requires
          # in +some+ instanaces that two or more letters sequentially be capitalized (addDeviceIDVDom).  Normal camelcase
          # processing usually takes care of this for us in instances where just first letter after an _ should be capital
          # but we don't want to force capitalizing only one or two letters in any otherwise lowercase :symbol so we adjust
          # the casing here using gsub
          querymsgxml = querymsgxml.gsub(/addDeviceIdVdom/, 'addDeviceIDVdom')
          querymsgxml = querymsgxml.gsub(/addDeviceSnVdom/, 'addDeviceSNVdom')
          querymsgxml = querymsgxml.gsub(/serialNumber/, 'SN')
          querymsgxml = querymsgxml.gsub(/devId/, 'ID')
          querymsgxml = querymsgxml.gsub(/vdomId/, 'vdomID')

          querymsgxml += '</addDeviceSNVdom>' if x[:serial_number]
          querymsgxml += '</addDeviceIDVdom>' if x[:dev_id] && !x[:serial_number]
        else
          raise ArgumentError.new('Must provide required arguments within the \"devices\" Array/Hash argument-> the 2nd argument (for devices to add) must contain (:serial_number or :dev_id) AND (:vdom_name or :vdom_id')
        end
        }
      elsif devices.is_a?(Hash)
          if devices[:serial_number] && devices[:vdom_name]
            querymsg[:add_device_sN_vdom] = {}
            querymsg[:add_device_sN_vdom][:serial_number] = devices[:serial_number]
            querymsg[:add_device_sN_vdom][:vdom_name] = devices[:vdom_name]
          elsif devices[:serial_number] && devices[:vdom_id]
            querymsg[:add_device_sN_vdom] = {}
            querymsg[:add_device_sN_vdom][:serial_number] = devices[:serial_number]
            querymsg[:add_device_sN_vdom][:vdom_id] = devices[:vdom_id]
          elsif devices[:dev_id] && devices[:vdom_name]
            querymsg[:add_device_iD_vdom] = {}
            querymsg[:add_device_iD_vdom][:iD] = devices[:dev_id]
            querymsg[:add_device_iD_vdom][:vdom_name] = devices[:vdom_name]
          elsif devices[:dev_id] && devices[:vdom_id]
            querymsg[:add_device_iD_vdom] = {}
            querymsg[:add_device_iD_vdom][:serial_number] = devices[:dev_id]
            querymsg[:add_device_iD_vdom][:vdom_id] = devices[:vdom_id]
          else
            raise ArgumentError.new('Must provide required arguments for method-> the 2nd argument (for devices to add) to add must contain :serial_number & (:vdom_name or :vdom_id')
          end
      end

      if meta.is_a?(Array)
        querymsgxml = Gyoku.xml(querymsg) + '<metafields>' unless querymsgxml
        meta.each { |x|
          if x[:name]  && x[:value]
            querymsgxml += '<metafield>' + Gyoku.xml(x) + '</metafield>'
          else
            raise ArgumentError.new('Must provide required arguments in \"metadata\" Hash/Array-> :name and :value')
          end
        }
        querymsgxml += '</metafields>'
      elsif meta.is_a?(Hash)
        if meta[:name] && meta[:value]
          querymsg[:metafields] = {:metafield => {:name => meta[:name], :value => meta[:value]}}
        else
          raise ArgumentError.new('Must provide required arguments in \"meta data\" Hash/Array-> :name and :value')
        end
      end

      if devices.is_a?(Array) || meta.is_a?(Array)
        exec_soap_query(:edit_adom,querymsgxml,:edit_adom_response,:error_msg)
      else
        exec_soap_query(:edit_adom,querymsg,:edit_adom_response,:error_msg)
      end
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## edit_group_membership Returns
  ##
  ## Retrieves ADOM info for a specified ADOM name and returns a hash of  attributes
  ##
  ## +Usage:+
  ##  get_adom_by_name() OR  # Note: If no parameter is passed defaults to 'root'
  ##  get_adom_by_name(:adom => 'adom_name')
  ################################################################################################
  def edit_group_membership(opts = {})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

    begin
      if opts[:grp_name]
        querymsg[:name] = opts[:grp_name]
      elsif opts[:grp_id]
        querymsg[:grp_id]
      else
        raise ArgumentError.new('Must provide required arguments for method->  :grp_name or :grp_id')
      end

      unless opts[:add_device_sn_list] || opts[:add_device_id_list] || opts[:del_device_sn_list] || opts[:del_device_id_list] || opts[:add_group_name_list] || \
       opts[:add_group_id_list] || opts[:del_group_name_list] || opts[:del_group_id_list]
        raise ArgumentError.new('No changes to make were provided')
      end

      querymsg[:add_device_sN_list] = opts[:add_device_sn_list] if opts[:add_device_sn_list]
      querymsg[:add_device_iD_list] = opts[:add_device_id_list] if opts[:add_device_id_list]
      querymsg[:del_device_sN_list] = opts[:del_device_sn_list] if opts[:del_device_sn_list]
      querymsg[:del_device_iD_list] = opts[:del_device_id_list] if opts[:del_device_id_list]
      querymsg[:add_group_name_list] = opts[:add_group_name_list] if opts[:add_group_name_list]
      querymsg[:add_group_iD_list] = opts[:add_group_iD_list] if opts[:add_group_iD_list]
      querymsg[:del_group_name_list] = opts[:del_group_name_list] if opts[:del_group_name_list]
      querymsg[:del_group_iD_list] = opts[:del_group_iD_list] if opts[:del_group_iD_list]

      exec_soap_query(:edit_group_membership,querymsg,:edit_group_membership_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ################################################################################################
  ## get_adom_by_name Returns Hash
  ##
  ## Retrieves ADOM info for a specified ADOM name and returns a hash of  attributes
  ##
  ## +Usage:+
  ##  get_adom_by_name() OR  # Note: If no parameter is passed defaults to 'root'
  ##  get_adom_by_name(:adom => 'adom_name')
  ################################################################################################
  def get_adom_by_name(opts = {})
    querymsg = @authmsg
    querymsg[:names] = opts[:adom] ? opts[:adom] : 'root'

    begin
      exec_soap_query(:get_adoms,querymsg,:get_adoms_response,:adom_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #############################################################################################
  ## get_adom_by_oid Returns Hash
  ##
  ## Retrieves VDOM info for a specified VDOM ID and returns a hash of VDOM attributes
  ##
  ## +Usage:+
  ##  get_adom_by_oid() OR  # If no parameter is passed, defaults to OID=3 (which should be root adom)]
  ##  get_adom_by_oid(:adom_id => 'adom_oid')
  #############################################################################################
  def get_adom_by_oid(opts = {})
    querymsg = @authmsg
    querymsg[:adom_ids] = opts[:adom_id] ? opts[:adom_id] : '3'

    begin
      exec_soap_query(:get_adoms,querymsg,:get_adoms_response,:adom_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################
  ## get_adom_list Returns Array of Hashes (unless not in ADOM mode then just single Hash)
  ##
  ## Retrieves ADOM details as hash of hashes with top key based on OID
  ##
  ## +Usage:+
  ##  get_adom_list()
  #####################################################################
  def get_adom_list
    querymsg = @authmsg

    begin
      exec_soap_query(:get_adom_list,querymsg,:get_adom_list_response,:adom_info)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_config Returns Hash
  ##
  ## Retrieves a specific configuration revision
  ##
  ## +Usage:+
  ##  get_config({:revision_number => 'rev-number', :serial_number => 'serial-number'}) OR
  ##  get_config({:revision_number => 'rev-number', :dev_id => 'device-id'})
  ##
  ## +Optional_Arguments:+
  ##  :adom   # ADOM name.  Defaults to root if not supplied
  #####################################################################################################################
  def get_config (opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] if opts[:adom]

    begin
      if opts[:serial_number] && opts[:revision_number]
        querymsg[:serial_number] = opts[:serial_number]
        querymsg[:revision_number] = opts[:revision_number]
      elsif opts[:dev_id] && opts[:revision_number]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:revision_number] = opts[:revision_number]
      else
        raise ArgumentError.new('Must provide arguments for method get_config-> :revision_number AND (:dev_name OR :dev_id)')
      end
      exec_soap_query(:get_config,querymsg,:get_config_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_config_revision_history Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves list of configurations from Revision History
  ##
  ## +Usage:+
  ##  get_config_revision_history(:serial_number => 'serial-number')  OR
  ##  get_config_revision_history(:dev_id => 'device-id)
  ##
  ## +Optional_Arguments:+
  ##  :checkin_user
  ##  :min_checkin_date
  ##  :max_checkin_date,  # if min and max are both passed and max occurs before min then no date filter will be used
  ##  :min_revision_number
  ##  :max_revision_number  # if min and max are both passed and min > max then no revision number filter will be used
  #####################################################################################################################
  def get_config_revision_history (opts={})
    querymsg = @authmsg
    querymsg[:checkin_user] = opts[:checkin_user] if opts[:checkin_user]


    ### Validate Min/Max checkin dates to verify they are properly formated for use by FMG and verify that if both
    ### min and max checkin dates have been provided that the min date comes before the max.  If not, execute without
    ### using checkin date filters.
    if opts[:min_checkin_date] && opts[:max_checkin_date]
      date_min_checkin = DateTime.parse(opts[:min_checkin_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
      date_max_checkin = DateTime.parse(opts[:max_checkin_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
      if date_max_checkin && date_min_checkin
        if date_max_checkin >= date_min_checkin
          querymsg[:min_checkin_date] = date_min_checkin
          querymsg[:max_checkin_date] = date_max_checkin
        else
          puts __method__.to_s  + ': :max_checkin_date provided comes before the :min_checkin_date provided, executing without min/max checkin-date filter'
        end
      else
        puts __method__.to_s  + ': Invalid date formats provided in attributes :max_checkin_date or :min_checkin_date, executing without min/max checkin-date filter'
      end
    elsif opts[:min_checkin_date]
      date_min_checkin = DateTime.parse(opts[:min_checkin_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
      querymsg[:min_checkin_date] = date_min_checkin if date_min_checkin
    elsif opts[:max_checkin_date]
      date_max_checkin = DateTime.parse(opts[:max_checkin_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
      querymsg[:max_checkin_date] = date_max_checkin if date_max_checkin
    end

    ### Validate that if min and max revision numbers are both passed that min is less than max or don't use revision
    ### number filtering in the search.
    if opts[:min_revision_number] && opts[:max_revision_number]
      if opts[:max_revision_number] >= opts[:min_revision_number]
        querymsg[:min_revision_number] = opts[:min_revision_number]
        querymsg[:max_revision_number] = opts[:max_revision_number]
      else
        puts __method__.to_s  + ':max_revision_number provided is less than :min_revision_number provided.  Executing without min/max revision number filter'
      end
    elsif opts[:min_revision_number] then querymsg[:min_revision_number] = opts[:min_revision_number]
    elsif opts[:max_revision_number] then querymsg[:max_revision_number] = opts[:max_revision_number]
    end

    ## Apply the rest of the filters and execute API call by calling exec_soap_query
    begin
      if opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      elsif opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      else
        raise ArgumentError.new('Must provide arguments for method get_config_revision_history-> :serial_number OR :dev_id')
      end
      exec_soap_query(:get_config_revision_history,querymsg,:get_config_revision_history_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_device Returns Hash
  ##
  ## Retrieves a list of vdoms or with arguments a vdom for a specific device id or device name.
  ##
  ## +Usage:+
  ##  get_device(:serial_number => 'serial-number')  OR
  ##  get_device(:dev_id => 'device-id')
  #####################################################################################################################
  def get_device (opts={})
    querymsg = @authmsg

    begin
      if opts[:serial_number]
        querymsg[:serial_numbers] = opts[:serial_number]
      elsif opts[:dev_id]
        querymsg[:dev_ids] = opts[:dev_id]
      else
        raise ArgumentError.new('Must provide arguments for method get_device_vdom_list->  :serial_number or :dev_id')
      end
      exec_soap_query(:get_devices,querymsg,:get_devices_response,:device_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end

  end

  #####################################################################################################################
  ## get_device_license_list Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves license info for managed devices
  ##
  ## +Usage:+
  ##  get_device_license_list()
  #####################################################################################################################
  def get_device_license_list
    querymsg = @authmsg

    begin
      exec_soap_query(:get_device_license_list,querymsg,:get_device_license_list_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_device_list Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves a list of managed devices from FMG, returns hash, or hash of hashes with primary key or
  ## on serial_number.
  ##
  ## +Usage:+
  ##  get_device_list() OR  #if no arguments are passed defaults to root ADOM
  ##  get_device_list(:adom => 'adom-name')
  #####################################################################################################################
  def get_device_list (opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:detail] = 1

    begin
      exec_soap_query(:get_device_list,querymsg,:get_device_list_response,:device_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_device_vdom_list Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves a list of vdoms or with arguments a vdom for a specific device id or device name.
  ##
  ## +Usage:+
  ##  get_device_vdom_list(:dev_name => 'device-name')  OR
  ##  get_device_vdom_list(:dev_id => 'device-id')
  #####################################################################################################################
  def get_device_vdom_list (opts={})
    querymsg = @authmsg

    begin
      if opts[:dev_name]
        querymsg[:dev_name] = opts[:dev_name]
      elsif opts[:dev_id]
        querymsg[:dev_iD] = opts[:dev_id]
      else
        raise ArgumentError.new('Must provide arguments for method get_device_vdom_list->  :dev_name or :dev_id')
      end
      exec_soap_query(:get_device_vdom_list,querymsg,:get_device_vdom_list_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_faz_archive Returns UU64 encoded String
  ##
  ## Retrieves specified archive file.  (File name is required and can be retrieved from associated FAZ log
  ## incident serial number)
  ##
  ## +Usage:+
  ##  get_faz_archive({:adom => 'adom-name', :dev_id => 'serial-number', :file_name => 'filename', :type => 'type'})
  ##
  ## Please note that in most cases dev_id means dev_id but for this query you must supply the serial number as
  ## the dev_id.
  ##
  ## Types are as follows:   1-Web, 2-Email, 3-FTP, 4-IM, 5-Quarantine, 6-IPS
  ##
  ## Also note, that although the WSDL claims that this query supports tar and gzip compression options I have not
  ## been able to get either of those to work.  if you specify tar the file is sent without compression (same as if
  ## you didn't specify) if you specify gzip it also requires to specify a password but if you do the query will
  ## always hang.
  #####################################################################################################################
  def get_faz_archive (opts={})
    querymsg = @authmsg
    #querymsg[:compression] = 'gzip'
    #querymsg[:zip_password] = 'test'

    begin
      if opts[:adom] && opts[:dev_id] && opts[:file_name] && opts[:type]
        querymsg[:adom] = opts[:adom]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:file_name] = opts[:file_name]
        querymsg[:type] = opts[:type]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :adom, :dev_id, :file_name, :type')
      end
      exec_soap_query(:get_faz_archive,querymsg,:get_faz_archive_response,:file_list)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_faz_config Returns Nori::StringWithAttributes   (resulting string contains configuration)
  ##
  ## Retrieves configuration of FortiAnalyzer or FortiAnalyzer.
  ##
  ## +Note+ - This class uses the SAVON GEM for SOAP/XML processing.  There is a bug in SAVON where it removes some of
  ## the whitespace charactiers including \n from the body elements of the request upon processing.   This causes
  ## the config file returned in this query to be mal-formatted.  I have submitted a bug report to the SAVON team
  ## via GITHUB.  They have responded that this will be fixed.  You can see the bug submission at:
  ## https://github.com/savonrb/savon/issues/574#issuecomment-42635095.   In the mean time, I have added some regex
  ## processing code to resolve the returned query so it is at least usable, however this has only been limitedly
  ## tested on a few configurations.
  ##
  ## +Usage:+
  ##  get_faz_config()
  #####################################################################################################################
  def get_faz_config
    querymsg = @authmsg

    begin
      result = exec_soap_query(:get_faz_config,querymsg,:get_faz_config_response,:config)

      # The following code is hopefully temporary.  Returned results from SAVON have much of whitespace especially
      # \n removed which causes the returned config to not work on FAZ/FMG if applied.  Please see notes in method
      # documentation above.
      result = result.gsub(/\s{2,}/,"\n")
      result = result.gsub(/([0-9a-zA-Z])(end)/, "\\1 \n\\2\n")
      result = result.gsub(/(end)([0-9a-zA-Z])/, "\\1 \n\\2\n")
      result = result.gsub(/([0-9])(config)/, "\\1\n\\2")
      return result
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end
  alias :get_fmg_config :get_faz_config

  #####################################################################################################################
  ## get_faz_generated_report Returns UU64 encoded String
  ##
  ##                      **************** Not Working ************************
  ##
  ## +Usage+:
  ##  get_faz_generated_report({:adom => 'adom_name', :dev_id => 'device_id, :file_name => 'filename', :type => 'type'})
  #####################################################################################################################
  def get_faz_generated_report (opts={})
    querymsg = @authmsg
    querymsg[:adom] = 'root'
    querymsg[:report_date] = '2014-04-25T14:36:05+00:00'
    querymsg[:report_name] = 'S-10002_t10002-Bandwidth and Applications Report-2014-04-25-0936'
    #querymsg[:report_name] = 'Bandwidth and Applications Report'
    #querymsg[:compression] = 'tar'

    exec_soap_query(:get_faz_generated_report,querymsg,:get_faz_generated_report_response,:return)

    #begin
    #  if opts.empty?
    #    raise ArgumentError.new('Must provide required arguments for method: :adom, :dev_id, :file_name, :type')
    #  else
    #    if opts.has_key?(:adom) && opts.has_key?(:report_date) && opts.has_key?(:report_name)
    #      querymsg.merge!(opts)
    #      result = exec_soap_query(:get_faz_generated_report,querymsg,:get_faz_generated_report_response,:return)
    #    end
    #  end
    #rescue Exception => e
    #  fmg_rescue(e)
    #  return e
    #end
  end

  #####################################################################################################################
  ## get_group_list Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves list of groups from FMG/FAZ.  Optionally can specify an ADOM in the passed arguments.  If no ADOM
  ## is specified then it will default to root ADOM.
  ##
  ## +Usage:+
  ##  get_group_list() OR
  ##  get_group_list (:adom => 'adom_name')
  #####################################################################################################################
  def get_group_list(opts={})
    querymsg = @authmsg
    querymsg[:detail] = 1
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

    begin
      exec_soap_query(:get_group_list,querymsg,:get_group_list_response,:group_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_groups Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves list of groups from FMG/FAZ.  Must specify either 'name' of group or 'group_id'.
  ##
  ## +Usage:+
  ##  get_group(:name => 'group_name')  OR
  ##  get_group(:groupid => 'group_id')
  ##
  ## +Optional_Arguments:+
  ##  :adom => 'adom_name'
  #####################################################################################################################
  def get_group(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

    begin
      if opts[:name] || opts[:groupid]
        querymsg[:names] = opts[:name] if opts[:name]
        querymsg[:grp_ids] = opts[:grp_id] if opts[:grp_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name OR :grp_id')
      end
      exec_soap_query(:get_groups,querymsg,:get_groups_response,:group_detail)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_instlog Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves installation logs for specified device
  ##
  ## +Usage:+
  ##  get_instlog(:dev_id => 'device_id')  OR
  ##  get_group(:serial_number=> 'serial_number')
  ##
  ## +Optional_Agruments:+
  ##  :task_id
  #####################################################################################################################
  def get_instlog(opts={})
    querymsg = @authmsg
    querymsg[:task_id] = opts[:task_id] if opts[:task_id]

    begin
      if opts[:dev_id] || opts[:serial_number]
        querymsg[:dev_id] = opts[:dev_id] if opts[:dev_id]
        querymsg[:serial_number] = opts[:serial_number] if opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :dev_id or :serial_number')
      end
      exec_soap_query(:get_instlog,querymsg,:get_instlog_response,:inst_log)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_package_list Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves policy package list.  Option to specify an ADOM or it defaults to root ADOM.
  ##
  ## +Usage:+
  ##  get_package_list()
  ##
  ## +Optional_Arguments:+
  ##  :adom
  #####################################################################################################################
  def get_package_list(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

    begin
      exec_soap_query(:get_package_list,querymsg,:get_package_list_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_script (Returns Hash)
  ##
  ## Retrieves script details.
  ##
  ## +Usage:+
  ##  get_script(:script_name => 'script_name')
  #####################################################################################################################
  def get_script(opts={})
    querymsg = @authmsg

    if opts[:script_name]
      querymsg[:name] = opts[:script_name]
    else
      raise ArgumentError.new('Must provide required arguments for method-> :dev_id or :serial_number')
    end

    begin
      exec_soap_query(:get_script,querymsg,:get_script_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_script_log Returns Hash
  ##
  ## Retrieves script log
  ##
  ## +Usage:+
  ##  get_script_log({:script_name => 'script_name', :dev_id => 'device_id'}) OR
  ##  get script_log({:script_name => 'script_name, :serial_number => 'serial_number})
  #####################################################################################################################
  def get_script_log(opts={})
    querymsg = @authmsg

    begin
      if opts[:script_name] && opts[:dev_id]
        querymsg[:script_name] = opts[:script_name]
        querymsg[:dev_id] = opts[:dev_id]
      elsif opts[:script_name] && opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method: (:script_name & :dev_id ) or (:script_name & :serial_number)')
      end
      exec_soap_query(:get_script_log,querymsg,:get_script_log_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_script_log_summary Returns Hash
  ##
  ## Retrieves summary of executed scripts for a specific device
  ##
  ## +Usage:+
  ##  get_script_log_summary(:dev_id => 'device_id') OR
  ##  get script_log_summary(:serial_number => 'serial_number)
  ##
  ## +Optional_Arguments:+
  ##  :max_logs  # defaults to 1000
  #####################################################################################################################
  def get_script_log_summary(opts={})
    querymsg = @authmsg
    querymsg[:max_logs] = opts[:max_logs] ? opts[:max_logs] : '1000'

    begin
      if opts[:dev_id] && opts[:serial_number]
        raise ArgumentError.new('Must provide required arguments for method-> :script_name OR :serial_number (not both)')
      elsif opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      elsif opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :script_name or :serial_number')
      end
      exec_soap_query(:get_script_log_summary,querymsg,:get_script_log_summary_response,:return)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_system_status Returns Hash
  ##
  ## Retrieves system status as has containing system variables and values.
  ##
  ## +Usage:+
  ##  get_system_status()
  #####################################################################################################################
  def get_system_status
    querymsg = @authmsg

    begin
      exec_soap_query_for_get_sys_status(:get_system_status,querymsg,:get_system_status_response)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## get_task_detail Returns Hash
  ##
  ## Retrieves details of a task
  ##
  ## +Usage:+
  ##  get_task_detail(:task_id => 'task-id') OR
  ##  get_task_detail({:task_id => 'task-id', adom=> 'adom_name'})   #if ADOM is not provided it defaults to root ADOM
  #####################################################################################################################
  def get_task_detail(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    
    begin
      if opts[:task_id] then
        querymsg[:task_id] = opts[:task_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :task_id')
      end
      exec_soap_query(:get_task_list,querymsg,:get_task_list_response,:task_list)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## import_policy Returns Nori::StringWithAttributes (returned string contains details of import if success)
  ##
  ## Imports a policy from managed device to FMG current config DB for that device.
  ##
  ## +Usage:+
  ##  import_policy({:adom_name => 'root', :dev_name => 'MSSP-1', :vdom_name => 'root'}) OR
  ##  import_policy({:adom_id => '3', :dev_id => '234', :vdom_id => '3'}) OR
  ##  import_policy({:adom_name => 'root', :dev_id => '234', :vdom_name => 'root'})
  #####################################################################################################################
  def import_policy(opts={})
    querymsg = @authmsg

    begin
      if opts[:adom_name] && opts[:dev_name] && opts[:vdom_name]
        querymsg[:adom_name] = opts[:adom_name]
        querymsg[:dev_name] = opts[:dev_name]
        querymsg[:vdom_name] = opts[:vdom_name]
      elsif opts[:adom_id] && opts[:dev_id] && opts[:vdom_id]
        querymsg[:adom_oid] = opts[:adom_id]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:vdom_id] = opts[:dev_id]
      elsif opts[:adom_name] && opts[:dev_name] && opts[:vdom_id]
        querymsg[:adom_name] = opts[:adom_name]
        querymsg[:dev_name] = opts[:dev_name]
        querymsg[:vdom_id] = opts[:vdom_id]
      elsif opts[:adom_name] && opts[:dev_id] && opts[:vdom_id]
        querymsg[:adom_name] = opts[:adom_name]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:vdom_id] = opts[:vdom_id]
      elsif opts[:adom_id] && opts[:dev_name] && opts[:vdom_name]
        querymsg[:adom_oid] = opts[:adom_id]
        querymsg[:dev_name] = opts[:dev_name]
        querymsg[:vdom_name] = opts[:vdom_name]
      elsif opts[:adom_id] && opts[:dev_name] && opts[:vdom_id]
        querymsg[:adom_oid] = opts[:adom_id]
        querymsg[:dev_name] = opts[:dev_name]
        querymsg[:vdom_id] = opts[:vdom_id]
      elsif opts[:adom_oid] && opts[:dev_id] && opts[:vdom_name]
        querymsg[:adom_oid] = opts[:adom_id]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:vdom_name] = opts[:vdom_name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> (:adom_id OR :adom_name) AND (:dev_id OR :dev_name) AND (:vdom_id OR :vdom_name)')
      end
     
      exec_soap_query(:import_policy,querymsg,:import_policy_response,:report)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## install_conifg Returns Nori::StringWithAttributes (string contains taskID of associated task)
  ##
  ## Installs a policy package to specified device.
  ##  Note that there is no argument validation in this method as there is in most other methods of this class.
  ##
  ## Required arguments:
  ##
  ## +Usage:+
  ##  install_config({:adom => 'root', :pkgoid => '572', :dev_id => '234'})
  ##
  ## +Optional_Arguments:+
  ##  :rev_name    # revision name of package revision to install.  If not specified installs most recent rev
  ##  :install_validate   # 0 or 1 for false or true.  If not specified defaults to no-validation.
  ##
  #####################################################################################################################
  def install_config(opts={})
    querymsg = @authmsg
    querymsg[:new_rev_name] = opts[:rev_name] if opts[:rev_name]
    querymsg[:install_validate] = opts[:validate] if opts[:validate]

    begin
      if opts[:adom] && opts[:pkgoid] && opts[:dev_id]
        querymsg[:adom] = opts[:adom]
        querymsg[:pkgoid] = opts[:oid]
        querymsg[:dev_id] = opts[:dev_id]
      elsif opts[:adom] && opts[:pkgoid] && opts[:serial_number]
        querymsg[:adom] = opts[:adom]
        querymsg[:pkgoid] = opts[:oid]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :adom AND :pkgoid AND (:dev_id OR :serial_number')
      end
      exec_soap_query(:install_config,querymsg,:install_config_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## list_faz_generated_reports Returns Hash or Array of Hashes
  ## (if multiple results are found then returns Array of Hashes)
  ##
  ## Retrieves a list of FAZ generated reports stored on FortiAnalyzer or FortiManager.   An ADOM & start/end dates
  ## can be optionally specified as a arguments.  If an ADOM is not specified as a parameter this method will default
  ## to retrieving a report list from the root ADOM. If start time is provided you must also pass end time and
  ## vice-versa.  Various time formats are supported including with/without dashes and with/without time. If
  ## date/time arguments are provided but format is not valid then will still run with out date/time filtering.
  ##
  ## +Usage:+
  ##   list_faz_generated_reports()
  ##
  ## +Optional_Arguments:+
  ##  :adom        # containing adom-name
  ##  :start_time  # => '2014-01-01T00:00:00'    earliest report time
  ##  :end_time    # => '2014-04-01T00:00:00'    latest report time
  #####################################################################################################################
  def list_faz_generated_reports(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

      if opts[:start_date] && opts[:end_date]
        startdate = DateTime.parse(opts[:start_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
        enddate = DateTime.parse(opts[:end_date]).strftime('%Y-%m-%dT%H:%M:%S') rescue false
        if startdate && enddate
          if enddate > startdate
            querymsg[:start_date] = startdate
            querymsg[:end_date] = enddate
          else
            puts __method__.to_s + ': End_date provided comes before the start_date provided, executing without date filter.'
          end
        else
          puts __method__.to_s  + ': Invalid date formats provided, executing without date filter.'
        end
      end

    begin
      exec_soap_query(:list_faz_generated_reports,querymsg,:list_faz_generated_reports_response,:report_list)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## list_revision_id Returns: Nori::StringWithAttributes (string contains revisionID requested)
  ##
  ## Retrieves revision IDs associated with a particular device and optionally revisions with specific name
  ##
  ## +Usage:+
  ##  list_revision_id(:serial_number => 'serial_number') OR
  ##  list_revision_id(:dev_id => 'device_id')
  ##
  ## +Optional_Arguments:+
  ##  rev_name   # Name of revision to get ID for, if not specified retrieves current revision
  #####################################################################################################################
  def list_revision_id(opts={})
    querymsg = @authmsg
    querymsg[:rev_name] = opts[:rev_name] if opts[:rev_name]

    begin
      if opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      elsif opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :dev_id OR :serial_number')
      end
      exec_soap_query(:list_revision_id,querymsg,:list_revision_id_response,:rev_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## remove_faz_archive Returns: Hash  (returned result contains error_code and
  ##  error_message hash keys.  :error_code=0 (successful), :error_code=1 (failed))
  ##
  ## Removes specified archive file.  (Filename is required and can be retrieved from associated FAZ log
  ## incident serial number)
  ##
  ## +Usage:+
  ##  remove_faz_archive({:adom => 'adom_name', :dev_id => 'serial_number', :file_name => 'filename', :type => 'type'})
  ##
  ## *Note* that in most cases dev_id means dev_id but for this query you must supply the serial number as
  ## the dev_id.
  ##
  ## Types are as follows:   1-Web, 2-Email, 3-FTP, 4-IM, 5-Quarantine, 6-IPS
  ##
  ## Filename must be known and can be found in the associated log file
  ##
  ## Also note, that although the WSDL claims that this query supports tar and gzip compression options I have not
  ## been able to get either of those to work.  if you specify tar the file is sent without compression (same as if
  ## you didn't specify) if you specify gzip it also requires to specify a password but if you do the query will
  ## always hang.
  #####################################################################################################################
  def remove_faz_archive (opts={})
    querymsg = @authmsg

    begin
      if opts[:adom] && opts[:dev_id] && opts[:file_name] && opts[:type]
        querymsg[:adom] = opts[:adom]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:file_name] = opts[:file_name]
        querymsg[:type] = opts[:type]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :adom, :dev_id, :file_name, :type')
      end
      exec_soap_query(:remove_faz_archive,querymsg,:remove_faz_archive_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## retrieve_config Returns: Nori::StringWithAttributes (Returned string contains the
  ## FortiManager task ID of the request.  Status of the request can be found by retrieving and analyzing the task
  ## by ID.)
  ##
  ## Retrieves configuration from managed device to FortiManager DB
  ##
  ## +Usage:+
  ##  retrieve_config(:serial_number => 'XXXXXXXXXXXXX') OR
  ##  retrieve_config(:dev_id => 'XXX')
  ##
  ## +Optional_Arguments:+
  ##  :rev_name   # Name to give to revision when saved to DB.  If not specified will be default naming.
  #####################################################################################################################
  def retrieve_config(opts={})
    querymsg = @authmsg
    querymsg[:new_rev_name] = opts[:rev_name] if opts[:rev_name]

    begin
      if opts[:serial_number]
        querymsg[:serial_number] = opts[:serial_number]
      elsif opts[:dev_id]
        querymsg[:dev_id] = opts[:dev_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :dev_id OR :serial_number')
      end
      exec_soap_query(:retrieve_config,querymsg,:retrieve_config_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## revert config Returns Hash  (Returned result contains error_code and error_message hash keys.
  ## :error_code=0 (successful), :error_code=1 (failed))
  ##
  ## Reapplies a previous revision of configuration history to the active config set for the specified device
  ##
  ## +Usage:+
  ##  revert_config({rev_id => 'rev#', :serial_number => 'XXXXXXXXXXXXX'}) OR
  ##  revert_config({rev_id => 'rev#', :dev_id => 'XXX'})
  #####################################################################################################################
  def revert_config(opts={})
    querymsg = @authmsg

    begin
      if opts[:serial_number] && opts[:rev_id]
        querymsg[:serial_number] = opts[:serial_number]
        querymsg[:rev_id] = opts[:rev_id]
      elsif opts[:dev_id] && opts[:rev_id]
        querymsg[:dev_id] = opts[:dev_id]
        querymsg[:rev_id] = opts[:rev_id]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :dev_id OR :serial_number in AND :rev_id')
      end
      exec_soap_query(:revert_config,querymsg,:revert_config_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## run_faz_report Returns Hash   (Returned result contains error_code and error_message hash keys.
  ##  :error_code=0 (successful), :error_code=1 (failed))
  ##
  ##   ************** Still need to identify filter options and test those *********
  ##
  ## +Usage:+
  ##  run_faz_report(:report_template => 'report_name')
  ##
  ## +Optional_Arguments:+
  ##  :filter  # Filter to apply to report when run
  ##  :adom    # Name of ADOM to run report from/within
  #####################################################################################################################
  def run_faz_report(opts = {})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:filter] = opts[:filter] if opts[:filter]

    begin
      if opts[:report_template]
        querymsg[:report_template] = opts[:report_template]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :adom AND :report_template')
      end
      exec_soap_query(:run_faz_report,querymsg,:run_faz_report_response,:error_msg)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## run_script Returns: Nori::StringWithAttributes  (returned value is task ID for script process)
  ##
  ## Executes script by name on FMG DB or FMG managed devices
  ##
  ## +Usage:+
  ##  run_script({:name => 'name-of-script', :serial_number => 'XXXXXXXXXXXXX'})
  ##
  ## +Optional_Arguments:+
  ##  :is_global  # (values: true or false) [default = false],
  ##  :run_on_db  # (values: true or false) [default = false],
  ##  :type       # (values CLI or TCL) [default = CLI]
  #####################################################################################################################
  def run_script(opts={})
    querymsg = @authmsg
    querymsg[:is_global] = opts[:is_global] ? opts[:is_global] : 'false'
    querymsg[:run_on_dB] = opts[:run_on_db] ? opts[:run_on_db] : 'false'
    querymsg[:type] = opts[:type] ? opts[:type] : 'CLI'


    begin
      if opts[:name] && opts[:serial_number]
        querymsg[:name] = opts[:name]
        querymsg[:serial_number] = opts[:serial_number]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name AND :serial_number')
      end
      exec_soap_query(:run_script,querymsg,:run_script_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## search_faz_log Returns Hash (for single log) or Array of Hashes (for multiple logs)
  ##
  ## +Usage:+
  ##  search_faz_log({:device_name => 'name-of-device', :search_criteria => 'srcp=x.x.x.x and XXXXX or .... etc'})
  ##
  ## +Optional_Arguments:+
  ##  :adom              # (values 'adom-names') [default => root]
  ##  :check_archive     # (values: 0, 1?) [default = 0]
  ##  :compression       # (values: tar, gzip) [default = tar]
  ##  :content           # (values:  logs, XXX, XXX) [default = logs]
  ##  :dlp_archive_type  # (values:  XXXX) [default: <not set>]
  ##  :format            # (values: rawFormat, XXXX) [default = rawFormat]
  ##  :log_type          # (values: traffic, event, antivirus, webfilter, intrusion, emailfilter, vulnerability, dlp, voip) [default = traffic],
  ##  :max_num_matches   # (values: 1-n) [default = 10],
  ##  :start_index       # (values: 1-n) [default = 1],
  ##
  #####################################################################################################################
  def search_faz_log(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'
    querymsg[:check_archive] = opts[:check_archive] ? opts[:check_archive] : '0'
    querymsg[:compression] = opts[:compression] ? opts[:check_compression] : 'tar'
    querymsg[:content] = opts[:content] ? opts[:content] : 'logs'
    querymsg[:format] = opts[:formate] ? opts[:format] : 'rawFormat'
    querymsg[:log_type] = opts[:log_type] ? opts[:log_type] : 'traffic'
    querymsg[:max_num_matches] = opts[:max_num_matches] && opts[:max_num_matches] > 0 ? opts[:max_num_matches] : '10'
    querymsg[:search_criteria] = opts[:search_criteria] ? opts[:search_criteria] : 'srcip=10.0.2.15'
    querymsg[:start_index] = opts[:start_index] && opts[:start_index] > 1 ? opts[:start_index] : '1'
    querymsg[:DLP_archive_type] = opts[:dlp_archive_type] if opts[:dlp_archive_type]

    begin
      if opts[:device_name]
        querymsg[:device_name] = opts[:device_name]
      else
        raise ArgumentError.new('Must provide required arguments for method-> :name AND :serial_number')
      end
      result = exec_soap_query(:search_faz_log,querymsg,:search_faz_log_response,:logs)
      return result[:data]
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  #####################################################################################################################
  ## set_faz_config Returns NoriStringWithAttributes  (returns string containing task ID)
  ##
  ## Sets configuration of FMG/FAZ itself with the config string containing CLI formatted config commands.
  ##
  ## +Usage:+
  ##  search_faz_log({:config =>  "configuration \n configuration \n ..."})
  #####################################################################################################################
  def set_faz_config(opts={})
    querymsg = @authmsg
    querymsg[:adom] = opts[:adom] ? opts[:adom] : 'root'

    begin
      if opts[:config]
        querymsg[:config] = opts[:config]
      else
        raise ArgumentError.new('Must provide required argument for method-> :config')
      end
      exec_soap_query(:set_faz_config,querymsg,:set_faz_config_response,:task_id)
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end
  alias :set_fmg_config :set_faz_config

##############################
 private
##############################

  ###############################################################################################
  ## exec_soap_query
  ##
  ## Executes the Savon API calls to FMG for each of the above methods (with a couple of exceptions)
  ###############################################################################################
  def exec_soap_query(querytype,querymsg,responsetype,infotype)

    ### Make SOAP call to FMG and store result in 'data'
    begin
      data = @client.call(querytype, message: querymsg).to_hash

    rescue Exception => e
        fmg_rescue(e)
        return e
    end

    begin
      ## This is a hack because delete_script doesn't return in the same format as every other query
      return '0' if responsetype == :delete_script_response
      ##

      # Check for API error response and return error if exists
      if data[responsetype].has_key?(:error_msg)
        if data[responsetype][:error_msg][:error_code].to_i != 0
          raise data[responsetype][:error_msg][:error_msg]
        else
          return data[responsetype][infotype]
        end
      else
        return data[responsetype][infotype]
      end
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end

  ##################################################################################################################
  ## exec_soap_query_for_get_sys_status
  ##
  ## Executes the Savon API calls to FMG for only the get_sys_status method because the FortiManager
  ## returns data without a container attribute as it does with all other queries so we must manually parse out
  ## each of the values returned specifically.
  #################################################################################################################
  def exec_soap_query_for_get_sys_status(querytype,querymsg,responsetype)

    ### Make SOAP call to FMG and store result in 'data'
    begin
      data = @client.call(querytype, message: querymsg).to_hash

    rescue Exception => e
      fmg_rescue(e)
      return e
    end

    begin
      # Check for API error response and return error if exists
      if data[responsetype].has_key?(:error_msg)
        if data[responsetype][:error_msg][:error_code].to_i != 0
          raise data[responsetype][:error_msg][:error_msg]
        else
          status_result = {
              :platform_type => data[responsetype][:platform_type],
              :version => data[responsetype][:version],
              :serial_number => data[responsetype][:serial_number],
              :bios_version =>  data[responsetype][:bios_version],
              :host_name => data[responsetype][:hostName],
              :max_num_admin_domains => data[responsetype][:max_num_admin_domains],
              :max_num_device_group => data[responsetype][:max_num_device_group],
              :admin_domain_conf => data[responsetype][:admin_domain_conf],
              :fips_mode => data[responsetype][:fips_mode]
          }
        end
      else
        status_result = {
            :platform_type => data[responsetype][:platform_type],
            :version => data[responsetype][:version],
            :serial_number => data[responsetype][:serial_number],
            :bios_version =>  data[responsetype][:bios_version],
            :host_name => data[responsetype][:hostName],
            :max_num_admin_domains => data[responsetype][:max_num_admin_domains],
            :max_num_device_group => data[responsetype][:max_num_device_group],
            :admin_domain_conf => data[responsetype][:admin_domain_conf],
            :fips_mode => data[responsetype][:fips_mode]
        }
      end
    rescue Exception => e
      fmg_rescue(e)
      return e
    end
  end


  #################################################################################
  ## fmg_rescue
  ##
  ## Provides style for rescue and error messaging
  #################################################################################
  def fmg_rescue(error)
    puts '### Error! ################################################################################################'
    puts error.message
    puts error.backtrace.inspect
    puts '###########################################################################################################'
    puts ''
  end
end
