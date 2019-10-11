import InstrumentManager from './contracts/InstrumentManagerInterface.json';
import InstrumentEscrow from './contracts/InstrumentEscrowInterface.json';
import SampleToken from './contracts/TokenMock.json';
import ParametersUtil from './contracts/ParametersUtil.json';

// Note: InstrumentManager and InstrumentEscrow are created in smart contract.
// So we need to hard code their address in corresponding networks here.

// Network 4 is Rinkeby
InstrumentManager["networks"]["4"] = {
    "address": "0x91d84aD3D0FFFae8f68205Baa7a216bcbFDd4E54",
    "transactionHash": "0x8f5b1809b5c87c10affa0aa770e1d7ca915088763d8c9f8d518b28d6199e0f39"
};

InstrumentEscrow["networks"]["4"] = {
    "address": "0xBbb3E3d228e5E59D9A9076e6526FF1ed9cd92aA2",
    "transactionHash": "0x8f5b1809b5c87c10affa0aa770e1d7ca915088763d8c9f8d518b28d6199e0f39"
};

const options = {
    web3: {
      block: false,
      fallback: {
        type: "ws",
        url: "ws://127.0.0.1:8545",
      },
    },
    contracts: [InstrumentManager, InstrumentEscrow, SampleToken, ParametersUtil],
    polls: {
      accounts: 1500,
    },
  };
  
  export default options;