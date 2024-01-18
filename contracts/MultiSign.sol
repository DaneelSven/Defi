// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* Custom errors */
error notOwner();
error txNotExists();
error alreadyExecuted();
error txAlreadyConfirmed();
error txNotConfirmed();
error ownersRequired();
error invalidReqConfirmations();
error invalidOwner();
error notUniqueOwner();
error cannotExecuteTx();
error failedTx();

/**
 * @title MultiSigWallet
 * @dev Implements a multisignature wallet. Transactions must be confirmed by multiple owners.
 */
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint amount, uint balance);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert notOwner();
        _;
    }

    modifier txExists(uint $txIndex) {
        if ($txIndex > transactions.length) revert txNotExists();
        _;
    }

    modifier notExecuted(uint $txIndex) {
        if (transactions[$txIndex].executed) revert alreadyExecuted();
        _;
    }

    modifier notConfirmed(uint $txIndex) {
        if (isConfirmed[$txIndex][msg.sender]) revert txAlreadyConfirmed();
        _;
    }

    /**
     * @dev Constructs the multisignature wallet with a set of owners and a required number of confirmations.
     * @param $owners The addresses that will be owners of the wallet.
     * @param $numConfirmationsRequired The number of confirmations required for a transaction.
     */
    constructor(address[] memory $owners, uint $numConfirmationsRequired) {
        if ($owners.length < 0) revert ownersRequired();
        if (
            numConfirmationsRequired < 0 &&
            numConfirmationsRequired >= $owners.length
        ) revert invalidReqConfirmations();

        for (uint i = 0; i < $owners.length; i++) {
            address owner = $owners[i];

            if (owner == address(0)) revert invalidOwner();
            if (isOwner[owner]) revert notUniqueOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = $numConfirmationsRequired;
    }

    /**
     * @dev Submits a transaction to be processed by the wallet.
     * @param $to The address the transaction will be sent to.
     * @param $value The amount of Ether to send.
     * @param $data The data to send with the transaction.
     */
    function submitTransaction(
        address $to,
        uint $value,
        bytes memory $data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: $to,
                value: $value,
                data: $data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, $to, $value, $data);
    }

    /**
     * @dev Confirms a transaction by an owner.
     * @param $txIndex The index of the transaction in the wallet's transaction array.
     */
    function confirmTransaction(
        uint $txIndex
    )
        public
        onlyOwner
        txExists($txIndex)
        notExecuted($txIndex)
        notConfirmed($txIndex)
    {
        Transaction storage transaction = transactions[$txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[$txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, $txIndex);
    }

    /**
     * @dev Executes a confirmed transaction.
     * @param $txIndex The index of the transaction in the wallet's transaction array.
     */
    function executeTransaction(
        uint $txIndex
    ) public onlyOwner txExists($txIndex) notExecuted($txIndex) {
        Transaction storage transaction = transactions[$txIndex];

        if (transaction.numConfirmations < numConfirmationsRequired)
            revert cannotExecuteTx();

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        if (!success) revert failedTx();

        emit ExecuteTransaction(msg.sender, $txIndex);
    }

    /**
     * @dev Revokes a confirmation for a transaction by an owner.
     * @param $txIndex The index of the transaction in the wallet's transaction array.
     */
    function revokeConfirmation(
        uint $txIndex
    ) public onlyOwner txExists($txIndex) notExecuted($txIndex) {
        Transaction storage transaction = transactions[$txIndex];

        if (!isConfirmed[$txIndex][msg.sender]) revert txNotConfirmed();

        transaction.numConfirmations -= 1;
        isConfirmed[$txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, $txIndex);
    }

    /**
     * @dev Returns the list of wallet owners.
     * @return List of owner addresses.
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Returns the total number of transactions submitted to the wallet.
     * @return The total number of transactions.
     */
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /**
     * @dev Returns details for a transaction.
     * @param $txIndex The index of the transaction in the wallet's transaction array.
     * @return to The recipient address of the transaction.
     * @return value The amount of Ether (in wei) to be sent.
     * @return data The data payload of the transaction.
     * @return executed Boolean representing whether the transaction has been executed.
     * @return numConfirmations The number of confirmations that the transaction has received.
     */
    function getTransaction(
        uint $txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[$txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    /**
     * @notice Function to allow contract to receive ether
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
