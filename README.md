A blockchain-based affordable housing solution that enables fractional ownership and transparent development through smart contracts.

## 🎯 Overview

This project solves housing accessibility for low-income families by tokenizing housing units, allowing fractional ownership, rental income sharing, and community governance through blockchain technology.

## ✨ Key Features

- 🏘️ **Fractional NFT Ownership** - Buy portions of housing units with tokens
- 💰 **Rental Income Sharing** - Earn passive income based on token ownership
- 🚧 **Construction Milestones** - Transparent project development tracking
- 📊 **Smart Rent Contracts** - Automated rental income distribution
- 🗳️ **Community DAO Governance** - Collective decision making
- 🔄 **Token Resale Mechanism** - Decentralized secondary market for token trading
- 🛡️ **Unit Insurance Pool** - Community-funded insurance for housing units to mitigate unexpected costs
- 📋 **Insurance Claims System** - File, approve, and process insurance claims for covered damages

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd Tokenized-Affordable-Housing-Scheme
clarinet check
```

### Testing
```bash
clarinet console
```

## 📋 Contract Functions

### 🏗️ Housing Management
- `create-housing-unit` - Create new tokenized housing unit
- `buy-tokens` - Purchase fractional ownership tokens
- `transfer-tokens` - Transfer tokens between users
- `list-tokens-for-sale` - List tokens for resale at specified price
- `buy-listed-tokens` - Purchase tokens from resale listings
- `cancel-token-listing` - Remove token listing from market
- `contribute-to-insurance` - Contribute to unit insurance pool
- `file-insurance-claim` - Submit insurance claim for damages
- `approve-insurance-claim` - Approve submitted insurance claims
- `pay-insurance-claim` - Process approved claims and distribute funds

### 🏗️ Construction Tracking
- `create-milestone` - Set development milestones
- `fund-milestone` - Contribute to milestone funding
- `complete-milestone` - Mark milestone as completed

### 💵 Income Distribution
- `deposit-rental-income` - Add rental income to contract
- `distribute-rental-income` - Distribute income to token holders
- `withdraw-balance` - Withdraw earned income

### 📊 Data Access
- `get-housing-unit` - View unit details
- `get-token-ownership` - Check ownership amount
- `get-milestone` - View milestone status
- `get-user-balance` - Check withdrawable balance
- `get-token-listing` - View resale listing details
- `get-insurance-pool` - Check insurance pool amount for a unit
- `get-insurance-claim` - View insurance claim details

## 💡 Usage Examples

### Creating a Housing Unit
```clarity
(contract-call? .housing-scheme create-housing-unit u1000 u50 u2000)
```

### Buying Tokens
```clarity
(contract-call? .housing-scheme buy-tokens u1 u100)
```

### Creating Construction Milestone
```clarity
(contract-call? .housing-scheme create-milestone u1 "Foundation Complete" u50000)
```

### Listing Tokens for Resale
```clarity
(contract-call? .housing-scheme list-tokens-for-sale u1 u50 u60)
```

### Contributing to Insurance Pool
```clarity
(contract-call? .housing-scheme contribute-to-insurance u1 u100)
```

### Filing Insurance Claim
```clarity
(contract-call? .housing-scheme file-insurance-claim u1 u500 "Water damage from burst pipe")
```

## 🔐 Security Features

- Owner-only administrative functions
- Input validation on all parameters
- Balance verification before transfers
- Milestone completion requirements

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test thoroughly with Clarinet
4. Submit pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or issues, please open a GitHub issue or contact the development team.

---

Built with ❤️ using Stacks and Clarity Smart Contracts
