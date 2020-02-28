pragma solidity 0.5.16;
import "./ProtoBufRuntime.sol";

library SupplementalLineItem {

  //enum definition
// Solidity enum definitions
enum Type {
    UnknownType,
    Payable
  }


// Solidity enum encoder
function encode_Type(Type x) internal pure returns (int64) {
    
  if (x == Type.UnknownType) {
    return 0;
  }

  if (x == Type.Payable) {
    return 1;
  }
  revert();
}


// Solidity enum decoder
function decode_Type(int64 x) internal pure returns (Type) {
    
  if (x == 0) {
    return Type.UnknownType;
  }

  if (x == 1) {
    return Type.Payable;
  }
  revert();
}


// Solidity enum definitions
enum State {
    UnknownState,
    Unpaid,
    Paid,
    Reinitiated
  }


// Solidity enum encoder
function encode_State(State x) internal pure returns (int64) {
    
  if (x == State.UnknownState) {
    return 0;
  }

  if (x == State.Unpaid) {
    return 1;
  }

  if (x == State.Paid) {
    return 2;
  }

  if (x == State.Reinitiated) {
    return 3;
  }
  revert();
}


// Solidity enum decoder
function decode_State(int64 x) internal pure returns (State) {
    
  if (x == 0) {
    return State.UnknownState;
  }

  if (x == 1) {
    return State.Unpaid;
  }

  if (x == 2) {
    return State.Paid;
  }

  if (x == 3) {
    return State.Reinitiated;
  }
  revert();
}


  //struct definition
  struct Data {
    uint8 id;
    SupplementalLineItem.Type lineItemType;
    SupplementalLineItem.State state;
    address obligatorAddress;
    address claimorAddress;
    address tokenAddress;
    uint256 amount;
    uint256 dueTimestamp;
    uint8 reinitiatedTo;
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
    uint[10] memory counters;
    uint256 fieldId;
    ProtoBufRuntime.WireType wireType;
    uint256 bytesRead;
    uint256 offset = p;
    uint256 pointer = p;
    while (pointer < offset + sz) {
      (fieldId, wireType, bytesRead) = ProtoBufRuntime._decode_key(pointer, bs);
      pointer += bytesRead;
      if (fieldId == 1) {
        pointer += _read_id(pointer, bs, r, counters);
      }
      else if (fieldId == 2) {
        pointer += _read_lineItemType(pointer, bs, r, counters);
      }
      else if (fieldId == 3) {
        pointer += _read_state(pointer, bs, r, counters);
      }
      else if (fieldId == 4) {
        pointer += _read_obligatorAddress(pointer, bs, r, counters);
      }
      else if (fieldId == 5) {
        pointer += _read_claimorAddress(pointer, bs, r, counters);
      }
      else if (fieldId == 6) {
        pointer += _read_tokenAddress(pointer, bs, r, counters);
      }
      else if (fieldId == 7) {
        pointer += _read_amount(pointer, bs, r, counters);
      }
      else if (fieldId == 8) {
        pointer += _read_dueTimestamp(pointer, bs, r, counters);
      }
      else if (fieldId == 9) {
        pointer += _read_reinitiatedTo(pointer, bs, r, counters);
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
  function _read_id(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint8 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint8(p, bs);
    if (isNil(r)) {
      counters[1] += 1;
    } else {
      r.id = x;
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
  function _read_lineItemType(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (int64 tmp, uint256 sz) = ProtoBufRuntime._decode_enum(p, bs);
    SupplementalLineItem.Type x = decode_Type(tmp);
    if (isNil(r)) {
      counters[2] += 1;
    } else {
      r.lineItemType = x;
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
  function _read_state(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (int64 tmp, uint256 sz) = ProtoBufRuntime._decode_enum(p, bs);
    SupplementalLineItem.State x = decode_State(tmp);
    if (isNil(r)) {
      counters[3] += 1;
    } else {
      r.state = x;
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
  function _read_obligatorAddress(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (address x, uint256 sz) = ProtoBufRuntime._decode_sol_address(p, bs);
    if (isNil(r)) {
      counters[4] += 1;
    } else {
      r.obligatorAddress = x;
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
  function _read_claimorAddress(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (address x, uint256 sz) = ProtoBufRuntime._decode_sol_address(p, bs);
    if (isNil(r)) {
      counters[5] += 1;
    } else {
      r.claimorAddress = x;
      if (counters[5] > 0) counters[5] -= 1;
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
  function _read_tokenAddress(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (address x, uint256 sz) = ProtoBufRuntime._decode_sol_address(p, bs);
    if (isNil(r)) {
      counters[6] += 1;
    } else {
      r.tokenAddress = x;
      if (counters[6] > 0) counters[6] -= 1;
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
  function _read_amount(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if (isNil(r)) {
      counters[7] += 1;
    } else {
      r.amount = x;
      if (counters[7] > 0) counters[7] -= 1;
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
  function _read_dueTimestamp(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint256 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint256(p, bs);
    if (isNil(r)) {
      counters[8] += 1;
    } else {
      r.dueTimestamp = x;
      if (counters[8] > 0) counters[8] -= 1;
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
  function _read_reinitiatedTo(
    uint256 p, 
    bytes memory bs, 
    Data memory r, 
    uint[10] memory counters
  ) internal pure returns (uint) {
    /**
     * if `r` is NULL, then only counting the number of fields.
     */
    (uint8 x, uint256 sz) = ProtoBufRuntime._decode_sol_uint8(p, bs);
    if (isNil(r)) {
      counters[9] += 1;
    } else {
      r.reinitiatedTo = x;
      if (counters[9] > 0) counters[9] -= 1;
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
    pointer += ProtoBufRuntime._encode_sol_uint8(r.id, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      2, 
      ProtoBufRuntime.WireType.Varint, 
      pointer, 
      bs
    );
    int64 _enum_lineItemType = encode_Type(r.lineItemType);
    pointer += ProtoBufRuntime._encode_enum(_enum_lineItemType, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      3, 
      ProtoBufRuntime.WireType.Varint, 
      pointer, 
      bs
    );
    int64 _enum_state = encode_State(r.state);
    pointer += ProtoBufRuntime._encode_enum(_enum_state, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      4, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_address(r.obligatorAddress, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      5, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_address(r.claimorAddress, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      6, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_address(r.tokenAddress, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      7, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_uint256(r.amount, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      8, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_uint256(r.dueTimestamp, pointer, bs);
    pointer += ProtoBufRuntime._encode_key(
      9, 
      ProtoBufRuntime.WireType.LengthDelim, 
      pointer, 
      bs
    );
    pointer += ProtoBufRuntime._encode_sol_uint8(r.reinitiatedTo, pointer, bs);
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
   * @param r The struct to be encoded
   * @return The number of bytes encoded in estimation
   */
  function _estimate(
    Data memory r
  ) internal pure returns (uint) {
    uint256 e;
    e += 1 + 4;
    e += 1 + ProtoBufRuntime._sz_enum(encode_Type(r.lineItemType));
    e += 1 + ProtoBufRuntime._sz_enum(encode_State(r.state));
    e += 1 + 23;
    e += 1 + 23;
    e += 1 + 23;
    e += 1 + 35;
    e += 1 + 35;
    e += 1 + 4;
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
    output.lineItemType = input.lineItemType;
    output.state = input.state;
    output.obligatorAddress = input.obligatorAddress;
    output.claimorAddress = input.claimorAddress;
    output.tokenAddress = input.tokenAddress;
    output.amount = input.amount;
    output.dueTimestamp = input.dueTimestamp;
    output.reinitiatedTo = input.reinitiatedTo;

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
//library SupplementalLineItem