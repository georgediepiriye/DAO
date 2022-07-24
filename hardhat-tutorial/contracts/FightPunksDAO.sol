// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for the FakeNFTMarketplace
 */
interface IFakeNFTMarketplace {
    /// @dev purchase() purchases an NFT from the FakeNFTMarketplace
    /// @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;

    /// @dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    /// @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the given _tokenId has already been purchased
    /// @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);
}

/**
 * Minimal interface for FightpunksNFT containing only two functions
 * that we are interested in
 */
interface IFightPunks {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract FightPunksDAO is Ownable {
    // struct named Proposal containing all relevant information
    struct Proposal {
        // nftTokenId - the tokenID of the NFT to purchase from FakeNFTMarketplace if the proposal passes
        uint256 nftTokenId;
        // deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded.
        uint256 deadline;
        // yayVotes - number of yay votes for this proposal
        uint256 yayVotes;
        // nayVotes - number of nay votes for this proposal
        uint256 nayVotes;
        // executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
        bool executed;
        // voters - a mapping of FightPunksNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
        mapping(uint256 => bool) voters;
    }

    // Create a mapping of ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    // Number of proposals that have been created
    uint256 public numProposals;

    //create instances of NFTMarketplace and NFT
    IFakeNFTMarketplace nftMarketplace;
    IFightPunks fightpunksNFT;

    // Create a payable constructor which initializes the contract
    // instances for FakeNFTMarketplace and FightPunksNFT
    // The payable allows this constructor to accept an ETH deposit when it is being deployed
    constructor(address _nfteMarketplace, address _fightpunksNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nfteMarketplace);
        fightpunksNFT = IFightPunks(_fightpunksNFT);
    }

    // Create a modifier which only allows a function to be
    // called by someone who owns at least one FightFunkyNFT

    modifier nftHolderOnly() {
        require(fightpunksNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    /// @dev createProposal allows a FightPunksNFT holder to create a new proposal in the DAO
    /// @param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
    /// @return Returns the proposal index for the newly created proposal
    function createProposal(uint256 _nftTokenId)
        external
        nftHolderOnly
        returns (uint256)
    {
        require(
            nftMarketplace.available(_nftTokenId),
            "NFT not available for sale"
        );
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        // Set the proposal's voting deadline to be (current time + 5 minutes)
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals--;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposal's deadline has not been exceeded yet
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    // An enum named Vote containing possible options for a vote
    enum Vote {
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    /// @dev voteOnProposal allows a FightPunksNFT holder to cast their vote on an active proposal
    /// @param proposalIndex - the index of the proposal to vote on in the proposals array
    /// @param vote - the type of vote they want to cast
    function voteOnProposal(uint proposalIndex, Vote vote)
        external
        nftHolderOnly
        activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];
        //check for the number of NFT owned by voter
        uint256 voterNftBalance = fightpunksNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        // Calculate how many NFTs are owned by the voter
        // that haven't already been used for voting on this proposal
        //loop through each token owned b the voter and assign it to token id
        //at each iteration
        for (uint256 i = 0; i < voterNftBalance; i++) {
            uint256 tokenId = fightpunksNFT.tokenOfOwnerByIndex(msg.sender, i);

            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }

        require(numVotes > 0, "Already voted");
        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    // A modifier which only allows a function to be
    // called if the given proposals' deadline HAS been exceeded
    // and if the proposal has not yet been executed

    modifier inactiveProposalOnly(uint proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "DEADLINE_NOT_EXCEEDED"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    /// @dev executeProposal allows any FightPunksNFT holder to execute a proposal after it's deadline has been exceeded
    /// @param proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(uint256 proposalIndex)
        external
        inactiveProposalOnly(proposalIndex)
        nftHolderOnly
    {
        Proposal storage proposal = proposals[proposalIndex];

        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance > nftPrice, "NOT ENOUGHT FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    /// @dev withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
    function withdrawEther() external onlyOwner {
        address owner = owner();
        uint256 amount = address(this).balance;
        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Transfer wasn't successful");
    }

    // The following two functions allow the contract to accept ETH deposits
    // directly from a wallet without calling a function
    receive() external payable {}

    fallback() external payable {}
}
