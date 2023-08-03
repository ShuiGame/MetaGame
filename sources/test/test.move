// Copyright 2023 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module shui_module::airdrop_test {
    // use std::debug::print;
    // use std::vector;
    use std::string;
    use sui::clock;
    // use sui::coin::{Coin, value, mint_for_testing};
    // use sui::sui::SUI;
    use sui::test_scenario::{
        Scenario, next_tx, begin, end, ctx, take_shared, return_shared, take_from_sender,return_to_sender
    };

    use shui_module::shui::{Self};
    use shui_module::metaIdentity::{Self};
    use shui_module::airdrop::{Self};
    use shui_module::founder_team_reserve::{Self};
    use shui_module::swap::{Self};

    // utilities
    fun scenario(): Scenario { begin(@0x1) }

    #[test]
    fun test_init() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;

        // init package
        next_tx(test, admin);
        {
            shui::init_for_test(test);
            metaIdentity::init_for_test(ctx(test));
            airdrop::init_for_test(ctx(test));
            swap::init_for_test(ctx(test));
            founder_team_reserve::init_for_test(ctx(test));
        };

        // funds split
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let shuiGlobal = take_shared<shui::Global>(test);
            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            return_shared(airdropGlobal);
            return_shared(shuiGlobal);
        };
        
        // register meta
        next_tx(test, admin);
        {
            let global = take_shared<metaIdentity::MetaInfoGlobal>(test);
            metaIdentity::mintMeta(
                &mut global,
                string::utf8(b"sean"),
                string::utf8(b"13262272231"),
                string::utf8(b"448651346@qq.com"),
                admin,
                ctx(test)
            );
            return_shared(global)
        };

        // start clock
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let timeCap = take_from_sender<airdrop::TimeCap>(test);
            let clock = clock::create_for_testing(ctx(test));
            clock::increment_for_testing(&mut clock, 80000);
            airdrop::start_timing(&mut airdropGlobal, timeCap, &clock);
            return_shared(airdropGlobal);
            clock::destroy_for_testing(clock);
        };

        // claim airdrop
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let clock = clock::create_for_testing(ctx(test));
            clock::increment_for_testing(&mut clock, 80002);
            let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
            airdrop::claim_airdrop(&mut airdropGlobal, &meta, &clock, ctx(test));
            clock::destroy_for_testing(clock);
            return_to_sender(test, meta);
            return_shared(airdropGlobal);
        };
        end(scenario);
    }
}