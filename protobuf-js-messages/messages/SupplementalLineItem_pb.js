/**
 * @fileoverview
 * @enhanceable
 * @suppress {messageConventions} JS Compiler reports an error if a variable or
 *     field starts with 'MSG_' and isn't a translatable message.
 * @public
 */
// GENERATED CODE -- DO NOT EDIT!

var jspb = require('google-protobuf');
var goog = jspb;
var global = Function('return this')();

var SolidityTypes_pb = require('./SolidityTypes_pb.js');
goog.object.extend(proto, SolidityTypes_pb);
goog.exportSymbol('proto.SupplementalLineItem', null, global);
goog.exportSymbol('proto.SupplementalLineItem.State', null, global);
goog.exportSymbol('proto.SupplementalLineItem.Type', null, global);
/**
 * Generated by JsPbCodeGenerator.
 * @param {Array=} opt_data Optional initial data array, typically from a
 * server response, or constructed directly in Javascript. The array is used
 * in place and becomes part of the constructed object. It is not cloned.
 * If no data is provided, the constructed object will be empty, but still
 * valid.
 * @extends {jspb.Message}
 * @constructor
 */
proto.SupplementalLineItem = function(opt_data) {
  jspb.Message.initialize(this, opt_data, 0, -1, null, null);
};
goog.inherits(proto.SupplementalLineItem, jspb.Message);
if (goog.DEBUG && !COMPILED) {
  /**
   * @public
   * @override
   */
  proto.SupplementalLineItem.displayName = 'proto.SupplementalLineItem';
}



if (jspb.Message.GENERATE_TO_OBJECT) {
/**
 * Creates an object representation of this proto suitable for use in Soy templates.
 * Field names that are reserved in JavaScript and will be renamed to pb_name.
 * To access a reserved field use, foo.pb_<name>, eg, foo.pb_default.
 * For the list of reserved names please see:
 *     com.google.apps.jspb.JsClassTemplate.JS_RESERVED_WORDS.
 * @param {boolean=} opt_includeInstance Whether to include the JSPB instance
 *     for transitional soy proto support: http://goto/soy-param-migration
 * @return {!Object}
 */
proto.SupplementalLineItem.prototype.toObject = function(opt_includeInstance) {
  return proto.SupplementalLineItem.toObject(opt_includeInstance, this);
};


/**
 * Static version of the {@see toObject} method.
 * @param {boolean|undefined} includeInstance Whether to include the JSPB
 *     instance for transitional soy proto support:
 *     http://goto/soy-param-migration
 * @param {!proto.SupplementalLineItem} msg The msg instance to transform.
 * @return {!Object}
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.SupplementalLineItem.toObject = function(includeInstance, msg) {
  var f, obj = {
    id: (f = msg.getId()) && SolidityTypes_pb.uint8.toObject(includeInstance, f),
    lineitemtype: jspb.Message.getFieldWithDefault(msg, 2, 0),
    state: jspb.Message.getFieldWithDefault(msg, 3, 0),
    obligatoraddress: (f = msg.getObligatoraddress()) && SolidityTypes_pb.address.toObject(includeInstance, f),
    claimoraddress: (f = msg.getClaimoraddress()) && SolidityTypes_pb.address.toObject(includeInstance, f),
    tokenaddress: (f = msg.getTokenaddress()) && SolidityTypes_pb.address.toObject(includeInstance, f),
    amount: (f = msg.getAmount()) && SolidityTypes_pb.uint256.toObject(includeInstance, f),
    duetimestamp: (f = msg.getDuetimestamp()) && SolidityTypes_pb.uint256.toObject(includeInstance, f),
    reinitiatedto: (f = msg.getReinitiatedto()) && SolidityTypes_pb.uint8.toObject(includeInstance, f)
  };

  if (includeInstance) {
    obj.$jspbMessageInstance = msg;
  }
  return obj;
};
}


/**
 * Deserializes binary data (in protobuf wire format).
 * @param {jspb.ByteSource} bytes The bytes to deserialize.
 * @return {!proto.SupplementalLineItem}
 */
proto.SupplementalLineItem.deserializeBinary = function(bytes) {
  var reader = new jspb.BinaryReader(bytes);
  var msg = new proto.SupplementalLineItem;
  return proto.SupplementalLineItem.deserializeBinaryFromReader(msg, reader);
};


/**
 * Deserializes binary data (in protobuf wire format) from the
 * given reader into the given message object.
 * @param {!proto.SupplementalLineItem} msg The message object to deserialize into.
 * @param {!jspb.BinaryReader} reader The BinaryReader to use.
 * @return {!proto.SupplementalLineItem}
 */
proto.SupplementalLineItem.deserializeBinaryFromReader = function(msg, reader) {
  while (reader.nextField()) {
    if (reader.isEndGroup()) {
      break;
    }
    var field = reader.getFieldNumber();
    switch (field) {
    case 1:
      var value = new SolidityTypes_pb.uint8;
      reader.readMessage(value,SolidityTypes_pb.uint8.deserializeBinaryFromReader);
      msg.setId(value);
      break;
    case 2:
      var value = /** @type {!proto.SupplementalLineItem.Type} */ (reader.readEnum());
      msg.setLineitemtype(value);
      break;
    case 3:
      var value = /** @type {!proto.SupplementalLineItem.State} */ (reader.readEnum());
      msg.setState(value);
      break;
    case 4:
      var value = new SolidityTypes_pb.address;
      reader.readMessage(value,SolidityTypes_pb.address.deserializeBinaryFromReader);
      msg.setObligatoraddress(value);
      break;
    case 5:
      var value = new SolidityTypes_pb.address;
      reader.readMessage(value,SolidityTypes_pb.address.deserializeBinaryFromReader);
      msg.setClaimoraddress(value);
      break;
    case 6:
      var value = new SolidityTypes_pb.address;
      reader.readMessage(value,SolidityTypes_pb.address.deserializeBinaryFromReader);
      msg.setTokenaddress(value);
      break;
    case 7:
      var value = new SolidityTypes_pb.uint256;
      reader.readMessage(value,SolidityTypes_pb.uint256.deserializeBinaryFromReader);
      msg.setAmount(value);
      break;
    case 8:
      var value = new SolidityTypes_pb.uint256;
      reader.readMessage(value,SolidityTypes_pb.uint256.deserializeBinaryFromReader);
      msg.setDuetimestamp(value);
      break;
    case 9:
      var value = new SolidityTypes_pb.uint8;
      reader.readMessage(value,SolidityTypes_pb.uint8.deserializeBinaryFromReader);
      msg.setReinitiatedto(value);
      break;
    default:
      reader.skipField();
      break;
    }
  }
  return msg;
};


/**
 * Serializes the message to binary data (in protobuf wire format).
 * @return {!Uint8Array}
 */
proto.SupplementalLineItem.prototype.serializeBinary = function() {
  var writer = new jspb.BinaryWriter();
  proto.SupplementalLineItem.serializeBinaryToWriter(this, writer);
  return writer.getResultBuffer();
};


/**
 * Serializes the given message to binary data (in protobuf wire
 * format), writing to the given BinaryWriter.
 * @param {!proto.SupplementalLineItem} message
 * @param {!jspb.BinaryWriter} writer
 * @suppress {unusedLocalVariables} f is only used for nested messages
 */
proto.SupplementalLineItem.serializeBinaryToWriter = function(message, writer) {
  var f = undefined;
  f = message.getId();
  if (f != null) {
    writer.writeMessage(
      1,
      f,
      SolidityTypes_pb.uint8.serializeBinaryToWriter
    );
  }
  f = message.getLineitemtype();
  if (f !== 0.0) {
    writer.writeEnum(
      2,
      f
    );
  }
  f = message.getState();
  if (f !== 0.0) {
    writer.writeEnum(
      3,
      f
    );
  }
  f = message.getObligatoraddress();
  if (f != null) {
    writer.writeMessage(
      4,
      f,
      SolidityTypes_pb.address.serializeBinaryToWriter
    );
  }
  f = message.getClaimoraddress();
  if (f != null) {
    writer.writeMessage(
      5,
      f,
      SolidityTypes_pb.address.serializeBinaryToWriter
    );
  }
  f = message.getTokenaddress();
  if (f != null) {
    writer.writeMessage(
      6,
      f,
      SolidityTypes_pb.address.serializeBinaryToWriter
    );
  }
  f = message.getAmount();
  if (f != null) {
    writer.writeMessage(
      7,
      f,
      SolidityTypes_pb.uint256.serializeBinaryToWriter
    );
  }
  f = message.getDuetimestamp();
  if (f != null) {
    writer.writeMessage(
      8,
      f,
      SolidityTypes_pb.uint256.serializeBinaryToWriter
    );
  }
  f = message.getReinitiatedto();
  if (f != null) {
    writer.writeMessage(
      9,
      f,
      SolidityTypes_pb.uint8.serializeBinaryToWriter
    );
  }
};


/**
 * @enum {number}
 */
proto.SupplementalLineItem.Type = {
  UNKNOWNTYPE: 0,
  PAYABLE: 1
};

/**
 * @enum {number}
 */
proto.SupplementalLineItem.State = {
  UNKNOWNSTATE: 0,
  UNPAID: 1,
  PAID: 2,
  REINITIATED: 3
};

/**
 * optional solidity.uint8 id = 1;
 * @return {?proto.solidity.uint8}
 */
proto.SupplementalLineItem.prototype.getId = function() {
  return /** @type{?proto.solidity.uint8} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.uint8, 1));
};


/** @param {?proto.solidity.uint8|undefined} value */
proto.SupplementalLineItem.prototype.setId = function(value) {
  jspb.Message.setWrapperField(this, 1, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearId = function() {
  this.setId(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasId = function() {
  return jspb.Message.getField(this, 1) != null;
};


/**
 * optional Type lineItemType = 2;
 * @return {!proto.SupplementalLineItem.Type}
 */
proto.SupplementalLineItem.prototype.getLineitemtype = function() {
  return /** @type {!proto.SupplementalLineItem.Type} */ (jspb.Message.getFieldWithDefault(this, 2, 0));
};


/** @param {!proto.SupplementalLineItem.Type} value */
proto.SupplementalLineItem.prototype.setLineitemtype = function(value) {
  jspb.Message.setProto3EnumField(this, 2, value);
};


/**
 * optional State state = 3;
 * @return {!proto.SupplementalLineItem.State}
 */
proto.SupplementalLineItem.prototype.getState = function() {
  return /** @type {!proto.SupplementalLineItem.State} */ (jspb.Message.getFieldWithDefault(this, 3, 0));
};


/** @param {!proto.SupplementalLineItem.State} value */
proto.SupplementalLineItem.prototype.setState = function(value) {
  jspb.Message.setProto3EnumField(this, 3, value);
};


/**
 * optional solidity.address obligatorAddress = 4;
 * @return {?proto.solidity.address}
 */
proto.SupplementalLineItem.prototype.getObligatoraddress = function() {
  return /** @type{?proto.solidity.address} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.address, 4));
};


/** @param {?proto.solidity.address|undefined} value */
proto.SupplementalLineItem.prototype.setObligatoraddress = function(value) {
  jspb.Message.setWrapperField(this, 4, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearObligatoraddress = function() {
  this.setObligatoraddress(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasObligatoraddress = function() {
  return jspb.Message.getField(this, 4) != null;
};


/**
 * optional solidity.address claimorAddress = 5;
 * @return {?proto.solidity.address}
 */
proto.SupplementalLineItem.prototype.getClaimoraddress = function() {
  return /** @type{?proto.solidity.address} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.address, 5));
};


/** @param {?proto.solidity.address|undefined} value */
proto.SupplementalLineItem.prototype.setClaimoraddress = function(value) {
  jspb.Message.setWrapperField(this, 5, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearClaimoraddress = function() {
  this.setClaimoraddress(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasClaimoraddress = function() {
  return jspb.Message.getField(this, 5) != null;
};


/**
 * optional solidity.address tokenAddress = 6;
 * @return {?proto.solidity.address}
 */
proto.SupplementalLineItem.prototype.getTokenaddress = function() {
  return /** @type{?proto.solidity.address} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.address, 6));
};


/** @param {?proto.solidity.address|undefined} value */
proto.SupplementalLineItem.prototype.setTokenaddress = function(value) {
  jspb.Message.setWrapperField(this, 6, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearTokenaddress = function() {
  this.setTokenaddress(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasTokenaddress = function() {
  return jspb.Message.getField(this, 6) != null;
};


/**
 * optional solidity.uint256 amount = 7;
 * @return {?proto.solidity.uint256}
 */
proto.SupplementalLineItem.prototype.getAmount = function() {
  return /** @type{?proto.solidity.uint256} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.uint256, 7));
};


/** @param {?proto.solidity.uint256|undefined} value */
proto.SupplementalLineItem.prototype.setAmount = function(value) {
  jspb.Message.setWrapperField(this, 7, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearAmount = function() {
  this.setAmount(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasAmount = function() {
  return jspb.Message.getField(this, 7) != null;
};


/**
 * optional solidity.uint256 dueTimestamp = 8;
 * @return {?proto.solidity.uint256}
 */
proto.SupplementalLineItem.prototype.getDuetimestamp = function() {
  return /** @type{?proto.solidity.uint256} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.uint256, 8));
};


/** @param {?proto.solidity.uint256|undefined} value */
proto.SupplementalLineItem.prototype.setDuetimestamp = function(value) {
  jspb.Message.setWrapperField(this, 8, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearDuetimestamp = function() {
  this.setDuetimestamp(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasDuetimestamp = function() {
  return jspb.Message.getField(this, 8) != null;
};


/**
 * optional solidity.uint8 reinitiatedTo = 9;
 * @return {?proto.solidity.uint8}
 */
proto.SupplementalLineItem.prototype.getReinitiatedto = function() {
  return /** @type{?proto.solidity.uint8} */ (
    jspb.Message.getWrapperField(this, SolidityTypes_pb.uint8, 9));
};


/** @param {?proto.solidity.uint8|undefined} value */
proto.SupplementalLineItem.prototype.setReinitiatedto = function(value) {
  jspb.Message.setWrapperField(this, 9, value);
};


/**
 * Clears the message field making it undefined.
 */
proto.SupplementalLineItem.prototype.clearReinitiatedto = function() {
  this.setReinitiatedto(undefined);
};


/**
 * Returns whether this field is set.
 * @return {boolean}
 */
proto.SupplementalLineItem.prototype.hasReinitiatedto = function() {
  return jspb.Message.getField(this, 9) != null;
};


goog.object.extend(exports, proto);
