// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC1155.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/*
* @title ERC1155 Contract for SpacegatePass
*
* @author Kevin Mauel | What The Commit https://what-the-commit.com
*/
contract SpacegatePass is ERC1155, PaymentSplitter {
    string public name_;
    string public symbol_;

    bool public publicSaleIsOpen;
    bool public allowlistIsOpen;

    uint8 private constant tokenId = 0;

    uint256 public constant mintPrice = 0.2 ether;

    uint256 public constant maxSupply = 2000;
    uint256 public currentSupply = 0;

    string public baseURI = "ipfs://QmRajAWu6uRWbm4awYUzX4fmGGyUBFFBL2NRXbxtNtpQpN";

    bytes32 private merkleRoot;
    address public owner;

    /// @notice Mapping of addresses who have claimed tokens
    mapping(address => uint256) public hasClaimed;

    /// @notice Thrown if address has already claimed
    error AlreadyClaimed();
    /// @notice Thrown if address/amount are not part of Merkle tree
    error NotInMerkle();
    /// @notice Thrown if bad price
    error PaymentNotCorrect();
    error NotOwner();
    error MintExceedsMaxSupply();
    error TooManyMintsPerTransaction();
    error PublicSaleNotStarted();
    error AllowlistSaleNotStarted();

    constructor(
        address[] memory payees,
        uint256[] memory shares_
    ) ERC1155() PaymentSplitter(payees, shares_) {
        owner = msg.sender;
        name_ = "Spacegate Pass";
        symbol_ = "SGP";
    }

    function name() public view returns (string memory) {
        return name_;
    }

    function symbol() public view returns (string memory) {
        return symbol_;
    }

    function uri(uint256 id) override public view virtual returns (string memory) {
        return baseURI;
    }

    function claim(
        address to,
        uint256 proofAmount,
        uint256 mintAmount,
        bytes32[] calldata proof
    ) external payable {
        if (!allowlistIsOpen) revert AllowlistSaleNotStarted();
        if (mintAmount > proofAmount) revert();
        // Verify merkle proof, or revert if not in tree
        bytes32 leaf = keccak256(abi.encodePacked(to, proofAmount));
        bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValidLeaf) revert NotInMerkle();
        // Throw if address has already claimed tokens
        if (hasClaimed[to] + mintAmount > proofAmount) revert AlreadyClaimed();

        if (msg.value != mintPrice * mintAmount) revert PaymentNotCorrect();

        // Set address to claimed
        hasClaimed[to] += mintAmount;

        // Mint tokens to address
        _mint(to, tokenId, mintAmount, "");
        currentSupply += mintAmount;
    }

    function publicMint(uint256 amount) external payable {
        if (!publicSaleIsOpen) revert PublicSaleNotStarted();
        if (amount > 5) revert TooManyMintsPerTransaction();
        if (currentSupply + amount > maxSupply) revert MintExceedsMaxSupply();
        if (msg.value != mintPrice * amount) revert PaymentNotCorrect();
        _mint(msg.sender, tokenId, amount, "");
        currentSupply += amount;
    }

    /// ============ Owner Functions ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();

        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setBools(bool allowlist, bool publicSale) external onlyOwner {
        allowlistIsOpen = allowlist;
        publicSaleIsOpen = publicSale;
    }

    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mint(to, tokenId, amount, "");
        currentSupply += amount;
    }
}