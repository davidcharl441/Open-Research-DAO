# 🧬 Open Research DAO

A decentralized autonomous organization for community-governed funding and peer review of scientific research proposals on the Stacks blockchain.

## 🌟 Features

- 🏛️ **Decentralized Governance**: Community members vote on research proposals
- 💰 **Funding Distribution**: Automatic funding release for approved proposals  
- 👥 **Membership System**: Stake-based voting power for DAO participation
- 📊 **Peer Review**: Submit and review research outcomes
- 🔍 **Transparent Process**: All votes and decisions recorded on-chain

## 🚀 Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet with STX tokens

### Installation

```bash
clarinet new open-research-dao
cd open-research-dao
```

Copy the contract code into `contracts/open-research-dao.clar`

## 📖 Usage

### 1. Join the DAO
Stake STX tokens to become a member and gain voting power:

```clarity
(contract-call? .open-research-dao join-dao u1000000)
```

### 2. Submit Research Proposal
Members can submit proposals requesting funding:

```clarity
(contract-call? .open-research-dao submit-proposal 
  "AI Safety Research" 
  "Investigating alignment mechanisms for large language models"
  u5000000)
```

### 3. Vote on Proposals
Cast votes using your voting power:

```clarity
(contract-call? .open-research-dao vote-on-proposal u1 true)
```

### 4. Finalize Voting
After voting period ends, finalize the proposal:

```clarity
(contract-call? .open-research-dao finalize-proposal u1)
```

### 5. Execute Funding
Release funds to approved proposals:

```clarity
(contract-call? .open-research-dao execute-funding u1)
```

### 6. Submit Research Results
Researchers submit their findings:

```clarity
(contract-call? .open-research-dao submit-research u1 "ipfs-hash-of-research-paper")
```

### 7. Peer Review
Community members review submitted research:

```clarity
(contract-call? .open-research-dao submit-peer-review u1001 u8 "ipfs-hash-of-review")
```

## 🔧 Contract Functions

### Public Functions
- `join-dao(stake-amount)` - Join DAO by staking STX
- `submit-proposal(title, description, funding-amount)` - Submit research proposal
- `vote-on-proposal(proposal-id, vote-for)` - Vote on proposals
- `finalize-proposal(proposal-id)` - Finalize voting results
- `execute-funding(proposal-id)` - Release funding to approved proposals
- `submit-research(proposal-id, submission-hash)` - Submit research results
- `submit-peer-review(submission-id, score, review-hash)` - Review research
- `increase-stake(additional-amount)` - Increase voting power

### Read-Only Functions
- `get-proposal(proposal-id)` - Get proposal details
- `get-member-info(member)` - Get member information
- `get-research-submission(submission-id)` - Get research submission
- `get-peer-review(submission-id, reviewer)` - Get peer review
- `get-dao-stats()` - Get DAO statistics

## 🏗️ Architecture

The contract implements:
- **Stake-based membership** with proportional voting power
- **Time-limited voting** periods (144 blocks ≈ 24 hours)
- **Automatic fund distribution** for approved proposals
- **Peer review system** with scoring (1-10 scale)
- **Research submission tracking** with IPFS hash storage

## 🧪 Testing

```bash
clarinet test
```

## 📊 DAO Statistics

Check current DAO status:

```clarity
(contract-call? .open-research-dao get-dao-stats)
```

Returns:
- Total members
- Total proposals  
- Contract balance

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
```

**Git Commit Message:**
```
feat: implement Open Research DAO MVP with governance, funding, and peer review
```

**GitHub Pull Request Title:**
```
