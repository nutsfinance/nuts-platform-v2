pragma solidity 0.5.16;
import "./ProtoBufRuntime.sol";

library Liability {

  //enum definition
// Solidity enum definitions
enum Role {
    Maker,
    Taker,
    CollateralCustodian
  }


// Solidity enum encoder
function encode_Role(Role x) internal pure returns (int64) {
    
  if (x == Role.Maker) {
    return 0;
  }

  if (x == Role.Taker) {
    return 1;
  }

  if (x == Role.CollateralCustodian) {
    return 2;
  }
  revert();
}


// Solidity enum decoder
function decode_Role(int64 x) internal pure returns (Role) {
    
  if (x == 0) {
    return Role.Maker;
  }

  if (x == 1) {
    return Role.Taker;
  }

  if (x == 2) {
    return Role.CollateralCustodian;
  }
  revert();
}


// Solidity enum definitions
enum Type {
    Payable
  }


// Solidity enum encoder
function encode_Type(Type x) internal pure returns (int64) {
    
  if (x == Type.Payable) {
    return 0;
  }
  revert();
}


// Solidity enum decoder
function decode_Type(int64 x) internal pure returns (Type) {
    
  if (x == 0) {
    return Type.Payable;
  }
  revert();
}


  //struct definition
  struct Data {
    uint8 id;
    Liability.Type liabilityType;
    Liability.Role obligator;
    Liability.Role claimor;
    address tokenAddress;
    uint256 amount;
    uint256 dueTimestamp;
    bool paidOff;
  }

  // Decoder section

  /**
   * @dev The main decoder for memory
   * @param bs The bytes array to be decoded
   * @return The decoded struct
   */
  function decode(bytes memory bs) internal pure returns (Data memory) {
    (Data memory x,) = _decode(32, bs, bs.length);
    return x;
  }

  /**
   * @dev The main decoder for storage
   * @param self The in-storage struct
   * @param bs The bytes array to be decoded
   */
  function decode(Data storage self, bytes memory bs) internal {
    (Data memory x,) = _decode(32, bs, bs.length);
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
  function _decode(uint p, bytes memory bs, uint sz)
      internal pure returns (Data memory, uint) {
    Data memory r;
    uint[9] memory counters;
    uint fieldId;
    ProtoBufRuntime.WireType wireType;
    uint bytesRead;
    uint offset = p;
    uint pointer = p;
    while(pointer < offset+sz) {
      (fieldId, wireType, bytesRead) = ProtoBufRuntime._decode_key(pointer, bs);
      pointer += bytesRead;
      if(fieldId == 1) {
        pointer += _read_id(pointer, bs, r, counters);
      }
      else if(fieldId == 2) {
        pointer += _read_liabilityType(pointer, bs, r, counters);
      }
      else if(fieldId == 3) {
        pointer += _read_obligator(pointer, bs, r, counters);
      }
      else if(fieldId == 4) {
        pointer += _read_claimor(pointer, bs, r, counters);
      }
      else if(fieldId == 5) {
        pointer += _read_tokenAddress(pointer, bs, r, counters);
      }
      else if(fieldId == 6) {
        pointer += _read_amount(pointer, bs, r, counters);
      }
      else if(fieldId == 7) {
        pointer += _read_dueTimestamp(pointer, bs, r, counters);
      }
      else if(fieldId == 8) {
        pointer += _read_paidOff(pointer, bs, r, counters);
      }
      
      else {
        if (wireType == ProtoBufRuntime.WireType.Fixed64) {
          uint size;
          (, size) = ProtoBufRuntime._decode_fixed64(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.Fixed32) {
          uint size;
          (, size) = ProtoBufRuntime._decode_fixed32(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.Varint) {
          uint size;
          (, size) = ProtoBufRuntime._decode_varint(pointer, bs);
          pointer += size;
        }
        if (wireType == ProtoBufRuntime.WireType.LengthDelim) {
          uint size;
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
  function _read_id(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint8 x, uint sz) = ProtoBufRuntime._decode_sol_uint8(p, bs);
    if(isNil(r)) {
      counters[1] += 1;
    } else {
      r.id = x;
      if(counters[1] > 0) counters[1] -= 1;
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
  function _read_liabilityType(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (int64 tmp, uint sz) = ProtoBufRuntime._decode_enum(p, bs);
    Liability.Type x = decode_Type(tmp);
    if(isNil(r)) {
      counters[2] += 1;
    } else {
      r.liabilityType = x;
      if(counters[2] > 0) counters[2] -= 1;
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
  function _read_obligator(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (int64 tmp, uint sz) = ProtoBufRuntime._decode_enum(p, bs);
    Liability.Role x = decode_Role(tmp);
    if(isNil(r)) {
      counters[3] += 1;
    } else {
      r.obligator = x;
      if(counters[3] > 0) counters[3] -= 1;
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
  function _read_claimor(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (int64 tmp, uint sz) = ProtoBufRuntime._decode_enum(p, bs);
    Liability.Role x = decode_Role(tmp);
    if(isNil(r)) {
      counters[4] += 1;
    } else {
      r.claimor = x;
      if(counters[4] > 0) counters[4] -= 1;
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
  function _read_tokenAddress(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (address x, uint sz) = ProtoBufRuntime._decode_sol_address(p, bs);
    if(isNil(r)) {
      counters[5] += 1;
    } else {
      r.tokenAddress = x;
      if(counters[5] > 0) counters[5] -= 1;
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
  function _read_amount(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if(isNil(r)) {
      counters[6] += 1;
    } else {
      r.amount = x;
      if(counters[6] > 0) counters[6] -= 1;
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
  function _read_dueTimestamp(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if(isNil(r)) {
      counters[7] += 1;
    } else {
      r.dueTimestamp = x;
      if(counters[7] > 0) counters[7] -= 1;
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
  function _read_paidOff(uint p, bytes memory bs, Data memory r, uint[9] memory counters) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (bool x, uint sz) = ProtoBufRuntime._decode_bool(p, bs);
    if(isNil(r)) {
      counters[8] += 1;
    } else {
      r.paidOff = x;
      if(counters[8] > 0) counters[8] -= 1;
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
    uint sz = _encode(r, 32, bs);
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
  function _encode(Data memory r, uint p, bytes memory bs)
      internal pure returns (uint) {
    uint offset = p;
    uint pointer = p;
    
    pointer += ProtoBufRuntime._encode_key(1, ProtoBufRuntime.WireType.LengthDelim, pointer, bs);
    pointer += ProtoBufRuntime._encode_sol_uint8(r.id, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(2, ProtoBufRuntime.WireType.Varint, pointer, bs);
    int64 _enum_liabilityType = encode_Type(r.liabilityType);
    pointer += ProtoBufRuntime._encode_enum(_enum_liabilityType, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(3, ProtoBufRuntime.WireType.Varint, pointer, bs);
    int64 _enum_obligator = encode_Role(r.obligator);
    pointer += ProtoBufRuntime._encode_enum(_enum_obligator, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(4, ProtoBufRuntime.WireType.Varint, pointer, bs);
    int64 _enum_claimor = encode_Role(r.claimor);
    pointer += ProtoBufRuntime._encode_enum(_enum_claimor, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(5, ProtoBufRuntime.WireType.LengthDelim, pointer, bs);
    pointer += ProtoBufRuntime._encode_sol_address(r.tokenAddress, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(6, ProtoBufRuntime.WireType.LengthDelim, pointer, bs);
    pointer += ProtoBufRuntime._encode_sol_uint256(r.amount, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(7, ProtoBufRuntime.WireType.LengthDelim, pointer, bs);
    pointer += ProtoBufRuntime._encode_sol_uint256(r.dueTimestamp, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(8, ProtoBufRuntime.WireType.Varint, pointer, bs);
    pointer += ProtoBufRuntime._encode_bool(r.paidOff, pointer, bs);
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
  function _encode_nested(Data memory r, uint p, bytes memory bs)
      internal pure returns (uint) {
    /**
     * First encoded `r` into a temporary array, and encode the actual size used.
     * Then copy the temporary array into `bs`.
     */
    uint offset = p;
    uint pointer = p;
    bytes memory tmp = new bytes(_estimate(r));
    uint tmpAddr = ProtoBufRuntime.getMemoryAddress(tmp);
    uint bsAddr = ProtoBufRuntime.getMemoryAddress(bs);
    uint size = _encode(r, 32, tmp);
    pointer += ProtoBufRuntime._encode_varint(size, pointer, bs);
    ProtoBufRuntime.copyBytes(tmpAddr + 32, bsAddr + pointer, size);
    pointer += size;
    delete tmp;
    return pointer - offset;
  }
  // estimator

  /**
   * @dev The estimator for a struct
   * @param r The struct to be encoded
   * @return The number of bytes encoded in estimation
   */
  function _estimate(Data memory r) internal pure returns (uint) {
    uint e;
    e += 1 + 4;
    e += 1 + ProtoBufRuntime._sz_enum(encode_Type(r.liabilityType));
    e += 1 + ProtoBufRuntime._sz_enum(encode_Role(r.obligator));
    e += 1 + ProtoBufRuntime._sz_enum(encode_Role(r.claimor));
    e += 1 + 23;
    e += 1 + 35;
    e += 1 + 35;
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
    output.id = input.id;
    output.liabilityType = input.liabilityType;
    output.obligator = input.obligator;
    output.claimor = input.claimor;
    output.tokenAddress = input.tokenAddress;
    output.amount = input.amount;
    output.dueTimestamp = input.dueTimestamp;
    output.paidOff = input.paidOff;

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
//library Liability
