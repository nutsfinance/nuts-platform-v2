import InstrumentManager from './contracts/InstrumentManagerInterface.json';
import InstrumentEscrow from './contracts/InstrumentEscrowInterface.json';
import SampleToken from './contracts/TokenMock.json';
import ParametersUtil from './contracts/ParametersUtil.json';
import Saving from './contracts/Saving.json';
import Lending from './contracts/Lending.json';
import Borrowing from './contracts/Borrowing.json';
import SpotSwap from './contracts/SpotSwap.json';

// Note: InstrumentManager and InstrumentEscrow are created in smart contract.
// So we need to hard code their address in corresponding networks here.

// Network 4 is Rinkeby
const SavingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
SavingInstrumentManager["contractName"] = "SavingInstrumentManager";
SavingInstrumentManager["networks"]["4"] = {
  "address": "0x688019Ba26F49D4Ec9131e05EF3CB2F54CC728E4",
  "transactionHash": "0xcaa55e75cb228af04bc47d9a42fd546de32b0deb1c08a07826e1c22c3bbff01c"
};
const SavingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
SavingInstrumentEscrow["contractName"] = "SavingInstrumentEscrow";
SavingInstrumentEscrow["networks"]["4"] = {
  "address": "0xc36810740FdB6b2e129B28478CF7B308AE4FAd39",
  "transactionHash": "0xcaa55e75cb228af04bc47d9a42fd546de32b0deb1c08a07826e1c22c3bbff01c"
};
Saving["networks"]["4"] = {
  "address": "0x2d69D75dAEFc5926b20389B3d97D16b82eB99306",
  "transactionHash": "0x283be3a9e9211826792659b0f9147494e8545f50093a5dfe455fdcd95b23aabd"
};


const LendingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
LendingInstrumentManager["contractName"] = "LendingInstrumentManager";
LendingInstrumentManager["networks"]["4"] = {
  "address": "0x53db607a8F42d372B2E5B02Ebd9133c1eF817C40",
  "transactionHash": "0xc613a971132480dbc8323926d563622e33d57369d40f4f90db726bf0de158381"
};
const LendingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
LendingInstrumentEscrow["contractName"] = "LendingInstrumentEscrow";
LendingInstrumentEscrow["networks"]["4"] = {
  "address": "0x4233955d5Aaf95040909425A43F9895182d20dBA",
  "transactionHash": "0xc613a971132480dbc8323926d563622e33d57369d40f4f90db726bf0de158381"
};
Lending["networks"]["4"] = {
  "address": "0xBF6eBd5f1184Ad4e6806ed058c624cce34647d40",
  "transactionHash": "0xced46a633256ffc8ce0801d8fdba8e299c9526e780e5a91a4d78e028a0ca6877"
};


const BorrowingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
BorrowingInstrumentManager["contractName"] = "BorrowingInstrumentManager";
BorrowingInstrumentManager["networks"]["4"] = {
  "address": "0x8c1B1bab1Ab57640fe545E315E55dE1eaBBA5Fb0",
  "transactionHash": "0x4e0a915abbc61bb95db079995c147dafae9e327d3ad18b56e696cb35e7301d15"
};
const BorrowingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
BorrowingInstrumentEscrow["contractName"] = "BorrowingInstrumentEscrow";
BorrowingInstrumentEscrow["networks"]["4"] = {
  "address": "0xd98233fAF95ca8f211a9192Bf8C1679aFbf748C0",
  "transactionHash": "0x4e0a915abbc61bb95db079995c147dafae9e327d3ad18b56e696cb35e7301d15"
};
Borrowing["networks"]["4"] = {
  "address": "0x895d1a149C8b631111A75f5311e73984e470337b",
  "transactionHash": "0x10382570c34935f970c265bd9ed756ad99b186cf447ec08746d9956709d76cba"
};

const SpotSwapInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
SpotSwapInstrumentManager["contractName"] = "SpotSwapInstrumentManager";
SpotSwapInstrumentManager["networks"]["4"] = {
  "address": "0xee9e285e45eE4cd95c2151413b266354172f7068",
  "transactionHash": "0x26b8bc574835dd88c76c7960e0636d57ba7698607df1f5ce3fa7ed31c992d3b0"
};
const SpotSwapInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
SpotSwapInstrumentEscrow["contractName"] = "SpotSwapInstrumentEscrow";
SpotSwapInstrumentEscrow["networks"]["4"] = {
  "address": "0x0274FdC5B070cf926FF2315E2F46D149e24D8859",
  "transactionHash": "0x26b8bc574835dd88c76c7960e0636d57ba7698607df1f5ce3fa7ed31c992d3b0"
};
SpotSwap["networks"]["4"] = {
  "address": "0x69b05780a5Ac2A65602b1E284D963238217d8a5D",
  "transactionHash": "0x066ac157d6e7ee103d2f171a1781cdedb55e0d89d27c16940d3360d1a89a9e8b"
};

const options = {
    web3: {
      block: false,
      fallback: {
        type: "ws",
        url: "ws://127.0.0.1:8545",
      },
    },
    contracts: [
      Saving,
      SavingInstrumentManager,
      SavingInstrumentEscrow,
      Lending,
      LendingInstrumentManager,
      LendingInstrumentEscrow,
      Borrowing,
      BorrowingInstrumentManager,
      BorrowingInstrumentEscrow,
      SpotSwap,
      SpotSwapInstrumentManager,
      SpotSwapInstrumentEscrow,
      SampleToken,
      ParametersUtil
    ],
    polls: {
      accounts: 1500,
    },
  };
  
  export default options;