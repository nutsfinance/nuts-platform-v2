pragma solidity ^0.5.0;

/**
 * Utility library to handle strings.
 */
library StringUtil {

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function concat(string memory a, uint256 b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function concat(string memory a, address b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function concat(uint256 a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function concat(address a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /**
     * Convert a unint data to string
     */
    function uintToString(uint data) internal pure returns (string memory) {
        return bytes32ToString(bytes32(data));
    }

    /**
     * Convert a bytes32 data to string
     */
    function bytes32ToString (bytes32 data) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }

    /**
     * Convert an address data to bytes
     */
    function addressToBytes(address x) internal pure returns (bytes memory) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++) {
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        }
        return b;
    }

    /**
     * Convert an address data to string
     */
    function addressToString(address x) internal pure returns (string memory) {
        return string(addressToBytes(x));
    }

    function addressToStringHex(address _addr) internal pure returns(string memory) {
      bytes32 value = bytes32(uint256(_addr));
      bytes memory alphabet = "0123456789abcdef";

      bytes memory str = new bytes(42);
      str[0] = '0';
      str[1] = 'x';
      for (uint i = 0; i < 20; i++) {
          str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
          str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
      }
      return string(str);
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     * Convert a bytes data to address
     */
    function bytesToAddress(bytes memory data) internal pure returns (address) {
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(data, 0x20), 0)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    /**
     * Convert a string to uint
     */
    function stringToUint(bytes memory b) internal pure returns (uint result) {
        uint i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    /**
     * Check whether a string is unit
     */
    function isUint(bytes memory b) internal pure returns (bool) {
        for (uint i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c < 48 || c > 57)   {
                return false;
            }
        }

        return true;
    }

    /**
     * Check whether two bytes arrays are the same
     */
    function equals(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }

        return true;
    }

    function equals(string memory a, string memory b) internal pure returns (bool) {
        return equals(bytes(a), bytes(b));
    }

    function isAddress(string memory a) internal pure returns (bool) {
        bytes memory tmp = bytes(a);
        return tmp.length == 42 && uint8(tmp[0]) == 48 && uint8(tmp[1]) == 120;
    }

    function stringToAddress(string memory a) internal pure returns (address) {
        bytes memory tmp = bytes(a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2){
            iaddr *= 256;
            b1 = uint8(tmp[i]);
            b2 = uint8(tmp[i+1]);

            if (b1 >= 97 && b1 <= 102) {
                // 'a' <= b1 <= 'f'
                b1 -= 87;
            } else if (b1 >= 65 && b1 <= 70) {
                // 'A' <= b1 <= 'F'
                b1 -= 55;
            } else if (b1 >= 48 && b1 <= 57) {
                // '0' <= b1 <= '9'
                b1 -= 48;
            }
            if (b2 >= 97 && b2 <= 102) {
                // 'a' <= b2 <= 'f'
                b2 -= 87;
            } else if (b2 >= 65 && b2 <= 70) {
                // 'A' <= b2 <= 'F'
                b2 -= 55;
            } else if (b2 >= 48 && b2 <= 57) {
                // '0' <= b2 <= '9'
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}
