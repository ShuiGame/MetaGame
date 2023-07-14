module shui_module::roles {
    use std::vector;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{TxContext};
    struct RuleInfo has key {
        id: UID,
        swap_per_reserve: vector<u64>,
        swap_ratio_vec :vector<u64>,
        swap_num_limit_vec:vector<u64>
    }

    fun init(ctx: &mut TxContext) {
        let global = RuleInfo {
            id: object::new(ctx),
            swap_per_reserve: init_reserve_vec(),
            swap_ratio_vec: init_ratio_vec(),
            swap_num_limit_vec: init_swap_num_limit(),
        };
        transfer::share_object(global);
    }

    fun init_reserve_vec(): vector<u64> {
        // order: [founder, cofounder, game_engine, tech_team, promote_team, partner, angle_inves, gold_reserve, meta_id]
        let vec = vector::empty<u64>();
        vector::push_back(&mut vec, 4_000_000);
        vector::push_back(&mut vec, 3_000_000);
        vector::push_back(&mut vec, 1_000_000);
        vector::push_back(&mut vec, 500_000);
        vector::push_back(&mut vec, 400_000);
        vector::push_back(&mut vec, 350_000);
        vector::push_back(&mut vec, 100_000);
        vector::push_back(&mut vec, 1_000_000_000);
        vector::push_back(&mut vec, 0);
        vec
    }

    fun init_ratio_vec(): vector<u64> {
        // order: [founder, cofounder, game_engine, tech_team, promote_team, partner, angle_inves, gold_reserve]
        let vec = vector::empty<u64>();
        vector::push_back(&mut vec, 500);
        vector::push_back(&mut vec, 500);
        vector::push_back(&mut vec, 500);
        vector::push_back(&mut vec, 500);
        vector::push_back(&mut vec, 400);
        vector::push_back(&mut vec, 350);
        vector::push_back(&mut vec, 250);
        vector::push_back(&mut vec, 100);
        vec
    }

    fun init_swap_num_limit(): vector<u64> {
        // order: [founder, cofounder, game_engine, tech_team, promote_team, partner, angle_inves, gold_reserve,]
        let vec = vector::empty<u64>();
        vector::push_back(&mut vec, 8000);
        vector::push_back(&mut vec, 6000);
        vector::push_back(&mut vec, 2000);
        vector::push_back(&mut vec, 1000);
        vector::push_back(&mut vec, 1000);
        vector::push_back(&mut vec, 1000);
        vector::push_back(&mut vec, 40);
        vector::push_back(&mut vec, 10_000_000_000);
        vec
    }

    public fun get_per_reserve_by_type(info: &RuleInfo, type:u64) : u64 {
        *vector::borrow(&info.swap_per_reserve, type)
    }

    public fun get_ratio_by_type(info: &RuleInfo, type:u64) : u64 {
        *vector::borrow(&info.swap_ratio_vec, type)
    }

    public fun get_swap_num_limit_by_type(info: &RuleInfo, type:u64) : u64 {
        *vector::borrow(&info.swap_ratio_vec, type)
    }
}