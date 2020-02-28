pragma solidity 0.5.16;
import "./ProtoBufRuntime.sol";

library InstrumentParameters {


  //struct definition
  struct Data {
    uint256 instrumentTerminationTimestamp;
    uint256 instrumentOverrideTimestamp;
    address brokerAddress;
    bool supportMakerWhitelist;
    bool supportTakerWhitelist;
  }

  // Decoder section

  /**
   * @dev The main decoder for memory
   * @param bs The bytes array to be decoded
   * @return The decoded struct
   */
  function decode(bytes memory bs) internal pure returns (Data memory) {
    (Data memory x, ) = _decode(32, bs, bs.length);
    return x;
  }

  /**
   * @dev The main decoder for storage
   * @param self The in-storage struct
   * @param bs The bytes array to be decoded
   */
  function decode(Data storage self, bytes memory bs) internal {
    (Data memory x, ) = _decode(32, bs, bs.length);
    store(x, self);
  }
  // inner decoder

  /**
   * @dev The decoder for internal usage
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param sz The number of bytes expected
   * @return The decoded struct
   * @return The number of bytes decoded
   */
  function _decode(uint256 p, bytes memory bs, uint256 sz)
    internal 
    pure 
    returns (Data memory, uint) 
  {
    Data memory r;
    uint[6] memory counters;
    uint256 fieldId;
    ProtoBufRuntime.WireType wireType;
    uint256 bytesRead;
    uint256 offset = p;
    uint256 pointer = p;
    while (pointer < offset + sz) {
      (fieldId, wireType, bytesRead) = ProtoBufRuntime._decode_key(pointer, bs);
      pointer += bytesRead;
      if (fieldId == 1) {
        pointer += _read_instrumentTerminationTimestamp(pointer, bs, r, counters);
      }
      else if (fieldId == 2) {
        pointer += _read_instrumentOverrideTimestamp(pointer, bs, r, counters);
      }
      else if (fieldId == 3) {
        pointer += _read_brokerAddress(pointer, bs, r, counters);
      }
      else if (fieldId == 4) {
        pointer += _read_supportMakerWhitelist(pointer, bs, r, counters);
      }
      else if (fieldId == 5) {
        pointer += _read_supportTakerWhitelist(pointer, bs, r, counters);
      }
      
      else {
        if (wireType == ProtoBufRuntime.WireType.Fixed64) {
          uint256 size;
          (, size) = ProtoBufRuntime._decode_fixed64(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.Fixed32) {
          uint256 size;
          (, size) = ProtoBufRuntime._decode_fixed32(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.Varint) {
          uint256 size;
          (, size) = ProtoBufRuntime._decode_varint(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.LengthDelim) {
          uint256 size;
          (, size) = ProtoBufRuntime._decode_lendelim(pointer, bs);
          pointer += size;
        }
      }

    }
    return (r, sz);
  }

  // field readers

  /**
   * @dev The decoder for reading a field
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param r The in-memory struct
   * @param counters The counters for repeated fields
   * @return The number of bytes decoded
   */
  function _read_instrumentTerminationTimestamp(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[6] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if (isNil(r)) {
      counters[1] += 1;
    } else {
      r.instrumentTerminationTimestamp = x;
      if (counters[1] > 0) counters[1] -= 1;
    }
    return sz;
  }

  /**
   * @dev The decoder for reading a field
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param r The in-memory struct
   * @param counters The counters for repeated fields
   * @return The number of bytes decoded
   */
  function _read_instrumentOverrideTimestamp(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[6] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if (isNil(r)) {
      counters[2] += 1;
    } else {
      r.instrumentOverrideTimestamp = x;
      if (counters[2] > 0) counters[2] -= 1;
    }
    return sz;
  }

  /**
   * @dev The decoder for reading a field
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param r The in-memory struct
   * @param counters The counters for repeated fields
   * @return The number of bytes decoded
   */
  function _read_brokerAddress(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[6] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (address x, uint256 sz) = ProtoBufRuntime._decode_sol_address(p, bs);
    if (isNil(r)) {
      counters[3] += 1;
    } else {
      r.brokerAddress = x;
      if (counters[3] > 0) counters[3] -= 1;
    }
    return sz;
  }

  /**
   * @dev The decoder for reading a field
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param r The in-memory struct
   * @param counters The counters for repeated fields
   * @return The number of bytes decoded
   */
  function _read_supportMakerWhitelist(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[6] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (bool x, uint256 sz) = ProtoBufRuntime._decode_bool(p, bs);
    if (isNil(r)) {
      counters[4] += 1;
    } else {
      r.supportMakerWhitelist = x;
      if (counters[4] > 0) counters[4] -= 1;
    }
    return sz;
  }

  /**
   * @dev The decoder for reading a field
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @param r The in-memory struct
   * @param counters The counters for repeated fields
   * @return The number of bytes decoded
   */
  function _read_supportTakerWhitelist(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[6] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (bool x, uint256 sz) = ProtoBufRuntime._decode_bool(p, bs);
    if (isNil(r)) {
      counters[5] += 1;
    } else {
      r.supportTakerWhitelist = x;
      if (counters[5] > 0) counters[5] -= 1;
    }
    return sz;
  }


  // Encoder section

  /**
   * @dev The main encoder for memory
   * @param r The struct to be encoded
   * @return The encoded byte array
   */
  function encode(Data memory r) internal pure returns (bytes memory) {
    bytes memory bs = new bytes(_estimate(r));
    uint256 sz = _encode(r, 32, bs);
    assembly {
      mstore(bs, sz)
    }
    return bs;
  }
  // inner encoder

  /**
   * @dev The encoder for internal usage
   * @param r The struct to be encoded
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @return The number of bytes encoded
   */
  function _encode(Data memory r, uint256 p, bytes memory bs)
    internal 
    pure 
    returns (uint) 
  {
    uint256 offset = p;
    uint256 pointer = p;
    
    pointer += ProtoBufRuntime._encode_key(
      1, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_uint256(r.instrumentTerminationTimestamp, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      2, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_uint256(r.instrumentOverrideTimestamp, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      3, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_address(r.brokerAddress, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      4, 
      ProtoBufRuntime.WireType.Varint, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_bool(r.supportMakerWhitelist, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      5, 
      ProtoBufRuntime.WireType.Varint, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_bool(r.supportTakerWhitelist, pointer, bs);
    return pointer - offset;
  }
  // nested encoder

  /**
   * @dev The encoder for inner struct
   * @param r The struct to be encoded
   * @param p The offset of bytes array to start decode
   * @param bs The bytes array to be decoded
   * @return The number of bytes encoded
   */
  function _encode_nested(Data memory r, uint256 p, bytes memory bs)
    internal 
    pure 
    returns (uint) 
  {
    /**
     * First encoded `r` into a temporary array, and encode the actual size used.
     * Then copy the temporary array into `bs`.
     */
    uint256 offset = p;
    uint256 pointer = p;
    bytes memory tmp = new bytes(_estimate(r));
    uint256 tmpAddr = ProtoBufRuntime.getMemoryAddress(tmp);
    uint256 bsAddr = ProtoBufRuntime.getMemoryAddress(bs);
    uint256 size = _encode(r, 32, tmp);
    pointer += ProtoBufRuntime._encode_varint(size, pointer, bs);
    ProtoBufRuntime.copyBytes(tmpAddr + 32, bsAddr + pointer, size);
    pointer += size;
    delete tmp;
    return pointer - offset;
  }
  // estimator

  /**
   * @dev The estimator for a struct
   * @return The number of bytes encoded in estimation
   */
  function _estimate(
    Data memory /* r */
  ) internal pure returns (uint) {
    uint256 e;
    e += 1 + 35;
    e += 1 + 35;
    e += 1 + 23;
    e += 1 + 1;
    e += 1 + 1;
    return e;
  }

  //store function
  /**
   * @dev Store in-memory struct to storage
   * @param input The in-memory struct
   * @param output The in-storage struct
   */
  function store(Data memory input, Data storage output) internal {
    output.instrumentTerminationTimestamp = input.instrumentTerminationTimestamp;
    output.instrumentOverrideTimestamp = input.instrumentOverrideTimestamp;
    output.brokerAddress = input.brokerAddress;
    output.supportMakerWhitelist = input.supportMakerWhitelist;
    output.supportTakerWhitelist = input.supportTakerWhitelist;

  }



  //utility functions
  /**
   * @dev Return an empty struct
   * @return The empty struct
   */
  function nil() internal pure returns (Data memory r) {
    assembly {
      r := 0
    }
  }

  /**
   * @dev Test whether a struct is empty
   * @param x The struct to be tested
   * @return True if it is empty
   */
  function isNil(Data memory x) internal pure returns (bool r) {
    assembly {
      r := iszero(x)
    }
  }
}
//library InstrumentParameters