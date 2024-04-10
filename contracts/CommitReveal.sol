
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error AlreadyRevealed();
error RevealNotMatchCommit();
error RevealLate();
error RevealTooEarly();

/**
 * @title CommitReveal
 * @dev Implements a commit-reveal scheme with added functionality for random number generation within a specified range.
 */
contract CommitReveal {
    uint8 public max = 100;

    constructor() {}

    /**
     * @dev Struct to store commit details, including the commit hash, the block number of the commit, and a flag indicating whether it has been revealed.
     */
    struct Commit {
        bytes32 commit;
        uint64 block;
        bool revealed;
    }

    // Mapping to track commits by addresses.
    mapping(address => Commit) public commits;

    /**
     * @dev Event emitted when a new commit is made.
     * @param sender Address of the sender making the commit.
     * @param dataHash Hash of the committed data.
     * @param block Block number when the commit was made.
     */
    event CommitHash(address indexed sender, bytes32 dataHash, uint64 block);

    /**
     * @dev Event emitted upon revealing a hash.
     * @param sender Address of the sender revealing the hash.
     * @param revealHash Hash being revealed.
     * @param random Resulting random number generated from the reveal.
     */
    event RevealHash(address indexed sender, bytes32 revealHash, uint256 random);

    /**
     * @dev Event emitted upon revealing an answer with a salt.
     * @param sender Address of the sender revealing the answer.
     * @param answer Answer being revealed.
     * @param salt Salt used in generating the commit hash.
     */
    event RevealAnswer(address indexed sender, bytes32 answer, bytes32 salt);

    /**
     * @dev Allows a user to make a commit with a hash of their data.
     * @param dataHash Hash of the data to commit.
     */
    function commit(bytes32 dataHash) public {
        commits[msg.sender].commit = dataHash;
        commits[msg.sender].block = uint64(block.number);
        commits[msg.sender].revealed = false;
        emit CommitHash(msg.sender, commits[msg.sender].commit, commits[msg.sender].block);
    }

    /**
     * @dev Allows a user to reveal their commit and generates a random number based on the blockhash and the revealed hash.
     * @param revealHash Hash to reveal, which should match the previously committed hash.
     */
    function reveal(bytes32 revealHash) public returns (uint256 _tokenId) {
        if (commits[msg.sender].revealed) revert AlreadyRevealed();
        if(commits[msg.sender].block + 10 <= block.number) revert RevealTooEarly();

        commits[msg.sender].revealed = true;
        if (getHash(revealHash) != commits[msg.sender].commit) revert RevealNotMatchCommit();
        if (uint64(block.number) >= commits[msg.sender].block + 250) revert RevealLate();

        bytes32 blockHash = blockhash(commits[msg.sender].block);
        uint256 tokenId = uint256(keccak256(abi.encodePacked(blockHash, revealHash))) % max;
        emit RevealHash(msg.sender, revealHash, tokenId);

        return tokenId;

    }

    /**
     * @dev Generates a hash of the provided data, used for commit verification.
     * @param data Data to hash.
     * @return Hash of the data.
     */
    function getHash(bytes32 data) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), data));
    }

    /**
     * @dev Allows a user to reveal an answer and a salt, verifying against the committed hash.
     * @param answer Answer to reveal.
     * @param salt Salt used during the commit.
     */
    function revealAnswer(bytes32 answer, bytes32 salt) public {
        if (commits[msg.sender].revealed) revert AlreadyRevealed();
        commits[msg.sender].revealed = true;

        if (getSaltedHash(answer, salt) != commits[msg.sender].commit) revert RevealNotMatchCommit();
        emit RevealAnswer(msg.sender, answer, salt);
    }

    /**
     * @dev Generates a salted hash of the provided data, used for commit verification with salt.
     * @param data Data to hash.
     * @param salt Salt to include in the hash.
     * @return Salted hash of the data.
     */
    function getSaltedHash(bytes32 data, bytes32 salt) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), data, salt));
    }
}
