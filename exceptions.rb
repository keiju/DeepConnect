
require "e2mmap"

module DeepConnect
  extend Exception2MessageMapper

  def_exception :NoInterfaceMethod, "No interface method(%s.%s)"

  def_exception :NoServiceError, "No such service(%s)"
  def_exception :CantSerializable, "%sはシリアライズできません"
  def_exception :CantDup, "%sはdupできません"
  def_exception :CantDeepCopy, "%sはdeep copyできません"

  def_exception :SessionServiceStopped, "Session service stopped"
  def_exception :DisconnectClient, "%sの接続が切れました"

  def_exception :InternalError, "DeepConnect internal error(%s)"
  def_exception :ProtocolError, "Protocol error!!"

  def self.InternalError(message)
    DC.Raise InternalError, message
  end
end

