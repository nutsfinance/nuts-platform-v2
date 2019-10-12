import InstrumentManager from './contracts/InstrumentManagerInterface.json';
import InstrumentEscrow from './contracts/InstrumentEscrowInterface.json';
import SampleToken from './contracts/TokenMock.json';
import ParametersUtil from './contracts/ParametersUtil.json';
import LendingV1 from './contracts/LendingV1.json';

// Note: InstrumentManager and InstrumentEscrow are created in smart contract.
// So we need to hard code their address in corresponding networks here.

// Network 4 is Rinkeby
InstrumentManager["networks"]["4"] = {
    "address": "0x06Af420D2467697d59d34c2486BDa5F280F21936",
    "transactionHash": "0xe9976deb8fc320b5b00eef5f3c46252e103f5e68354c910b2e7996efc8b9d526"
};

InstrumentEscrow["networks"]["4"] = {
    "address": "0xa026C2b4D730F615A0f9664B96b7A62af05879d9",
    "transactionHash": "0xe9976deb8fc320b5b00eef5f3c46252e103f5e68354c910b2e7996efc8b9d526"
};

const options = {
    web3: {
      block: false,
      fallback: {
        type: "ws",
        url: "ws://127.0.0.1:8545",
      },
    },
    contracts: [InstrumentManager, InstrumentEscrow, SampleToken, ParametersUtil, LendingV1],
    polls: {
      accounts: 1500,
    },
  };
  
  export default options;