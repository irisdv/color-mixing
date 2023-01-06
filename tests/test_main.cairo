%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.utils.math64x61 import Math64x61
from starkware.cairo.common.math import assert_le, assert_not_zero, unsigned_div_rem
from src.constants import Color, Latent
from src.interface import IMix

@external
func __setup__() {
    %{
        context.data1 = deploy_contract("./src/data/data1.cairo", []).contract_address
        context.data2 = deploy_contract("./src/data/data2.cairo", []).contract_address
        context.data3 = deploy_contract("./src/data/data3.cairo", []).contract_address
        context.data4 = deploy_contract("./src/data/data4.cairo", []).contract_address
        context.data5 = deploy_contract("./src/data/data5.cairo", []).contract_address

        context.mix = deploy_contract("./src/mix.cairo", [5, context.data1, context.data2, context.data3, context.data4, context.data5]).contract_address
    %}
    return ();
}

@external
func test_mixbox{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    local main_addr;
    %{ ids.main_addr = context.mix %}

    // Mix color1 and color2 in equal proportions
    // color1 = (0, 33, 133)
    // color2 = (252, 211, 0)
    // t = 0.5

    let color1 = Color(r=0, g=76092819304051900416, b=306677120225421295616);
    let color2 = Color(r=581072438321850875904, g=486532874944089423872, b=0);

    let (mix: Color) = IMix.mix(main_addr, color1, color2, 1152921504606846976);
    assert Math64x61.toFelt(mix.r) = 41;
    assert Math64x61.toFelt(mix.g) = 130;
    assert Math64x61.toFelt(mix.b) = 57;

    // Mix multiple colors
    // color3 = (100, 10, 50)
    // 30% of color1, 60% of color2, 10% of color3

    let color3 = Color(r=230584300921369395200, g=23058430092136939520, b=115292150460684697600);

    let (rgb: Color) = IMix.mix_multiple(
        main_addr,
        3,
        cast(new (color1, color2, color3), Color*),
        3,
        cast(new (691752902764108186, 1383505805528216371, 230584300921369395), felt*),
    );

    assert Math64x61.toFelt(rgb.r) = 91;
    assert Math64x61.toFelt(rgb.g) = 135;
    assert Math64x61.toFelt(rgb.b) = 46;

    return ();
}
