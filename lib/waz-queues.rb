require 'time'
require 'cgi'
require 'base64'
require 'rexml/document'
require 'rexml/xpath'

require 'restclient'
require 'hmac-sha2'

$:.unshift(File.dirname(__FILE__))

require 'waz/queues/exceptions'
require 'waz/queues/service'
require 'waz/queues/version'


