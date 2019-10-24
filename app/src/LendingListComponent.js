import React, { Component } from 'react';
import Table from '@material-ui/core/Table';
import TableBody from '@material-ui/core/TableBody';
import TableCell from '@material-ui/core/TableCell';
import TableHead from '@material-ui/core/TableHead';
import TableRow from '@material-ui/core/TableRow';

class LendingListComponent extends Component {
    state = {issuances: []};

    componentDidMount() {
        const { drizzle } = this.props;
        const web3 = drizzle.web3;
        const lendingContract = drizzle.contracts.Lending;
        const lendingContractWeb3 = new web3.eth.Contract(lendingContract.abi, lendingContract.address);
        lendingContractWeb3.getPastEvents(
          'allEvents',
          {
            fromBlock: 0,
            toBlock: 'latest'
          }
        ).then(results => {
            console.log(results);
            // let issuances = [];
            // for (const result of results) {
            //     issuances.push({
            //         id: result.returnValues.issuanceId,
            //         collateralToken: result.returnValues.collateralTokenAddress,
            //         lendingToken: result.returnValues.lendingTokenAddress,
            //         lendingAmount: result.returnValues.lendingAmount,
            //         maker: result.returnValues.makerAddress,
            //         escrow: result.returnValues.escrowAddress,
            //     });
            // }
            
            // this.setState({issuances});
        });
    }

    render() {
        console.log(this.state.issuances);
        return (
            <div>
                <h3>Issuance List</h3>
                <Table>
                    <TableHead>
                    <TableRow>
                        <TableCell>ID</TableCell>
                        <TableCell align="right">Lending Amount</TableCell>
                        <TableCell align="right">Maker</TableCell>
                        <TableCell align="right">Escrow</TableCell>
                    </TableRow>
                    </TableHead>
                    <TableBody>
                    {this.state.issuances.map(issuance => (
                        <TableRow key={issuance.id}>
                            <TableCell>{issuance.id}</TableCell>
                            <TableCell align="right">{issuance.lendingAmount}</TableCell>
                            <TableCell align="right">{issuance.maker}</TableCell>
                            <TableCell align="right">{issuance.escrow}</TableCell>
                        </TableRow>
                    ))}
                    </TableBody>
                </Table>
            </div>
        );
    }
}

export default LendingListComponent;