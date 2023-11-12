module shui_module::royalty_policy {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap,
        TransferRequest,
    };
    use sui::package::Publisher;
    use sui::transfer;

    struct Rule has drop {}

    struct Config has store, drop {
        amount_bp: u16,
        beneficiary: address
    }

    // every transaction has to pay amount_bp to somebody
    public fun new_royalty_policy<T:key + store>(
        publisher: &Publisher,
        amount_bp: u16,
        ctx: &mut TxContext
    ) {
        let (policy, cap) = policy::new<T>(publisher, ctx);
        set<T>(&mut policy, &cap, amount_bp);
        transfer::public_share_object(policy);
        transfer::public_transfer(cap, sender(ctx));
    }

    public fun royalty_policy<T:key + store>(
        publisher: &Publisher,
        amount_bp: u16,
        ctx: &mut TxContext
    ) : TransferPolicy<T> {
        let (policy, cap) = policy::new<T>(publisher, ctx);
        set<T>(&mut policy, &cap, amount_bp);
        transfer::public_transfer(cap, sender(ctx));
        policy
    }

    // pay to beneficial
    public fun set<T:key + store>(
        policy: &mut TransferPolicy<T>,
        cap: &TransferPolicyCap<T>,
        amount_bp: u16
    ) {
        assert!(amount_bp < 10000, 0x02);
        policy::add_rule(Rule {}, policy, cap, Config { amount_bp, beneficiary: @account })
    }

    public fun pay<T:key + store>(
        policy: &TransferPolicy<T>,
        request: &mut TransferRequest<T>,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let config: &Config = policy::get_rule(Rule {}, policy);
        let paid = policy::paid(request);
        let amount = calculate(config.amount_bp, paid);

        assert!(coin::value(payment) >= amount, 0x01);

        if (amount > 0) {
            let fee = coin::split(payment, amount, ctx);
            transfer::public_transfer(fee, config.beneficiary);
        };
        policy::add_receipt(Rule {}, request)
    }

    public fun calculate_royalty<T:key + store>(
        policy: &TransferPolicy<T>,
        paid: u64
    ): u64 {
        let config: &Config = policy::get_rule(Rule {}, policy);

        return calculate(config.amount_bp, paid)
    }

    public fun calculate(amount_bp: u16, paid: u64): u64 {
        (((paid as u128) * (amount_bp as u128) / 10000) as u64)
    }
}