%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.utils.math64x61 import Math64x61
from starkware.cairo.common.math import assert_le, assert_not_zero, unsigned_div_rem
from src.constants import Color
from src.mix import (
    _clamp01, 
    eval_polynomial, 
    latent_to_rgb, 
    lerp_latent, 
    get_c, 
    compute_latent,
    float_rgb_to_latent,
    rgb_to_latent
)

@external
func test_clamp{bitwise_ptr : BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let (is_inf) = _clamp01(-2305843009213693952);
    assert Math64x61.toFelt(is_inf) = 0;

    let (is_sup) = _clamp01(Math64x61.fromFelt(2));
    assert Math64x61.toFelt(is_sup) = 1;

    let (is_ok) = _clamp01(1152921504606846976);
    assert is_ok = 1152921504606846976;

    return ();
}