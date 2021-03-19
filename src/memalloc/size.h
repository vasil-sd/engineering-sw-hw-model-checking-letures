#pragma once

#include <cstddef>
#include <cstdint>
#include <limits>
#include <iostream>
#include <cassert>

/*
эта функция нужна для выравнивания адресов и размеров
*/
size_t constexpr align(size_t s, size_t alignment = 8) {
    assert((alignment & (alignment - 1)) == 0);
    --alignment;
    s += alignment;
    s &= ~alignment;
    return s;
}

class Size {
public:
    Size(size_t sz) : sz_{sz} {}
    Size() = default;
    Size(const Size&) = default;
    Size(Size&&) = default;
    Size& operator=(const Size&) = default;
    Size& operator=(Size&&) = default;
    ~Size() = default;

    Size operator+(const Size& s) const { return {sz_ + s.sz_}; }
    Size operator-(const Size& s) const { assert(sz_ >= s.sz_); return {sz_ - s.sz_}; }

    bool operator==(const Size& s) const { return sz_ == s.sz_; }
    bool operator!=(const Size& s) const { return sz_ != s.sz_; }
    bool operator>(const Size& s) const { return sz_ > s.sz_; }
    bool operator>=(const Size& s) const { return sz_ >= s.sz_; }
    bool operator<(const Size& s) const { return sz_ < s.sz_; }
    bool operator<=(const Size& s) const { return sz_ >= s.sz_; }

    static const Size zero;
    static const Size max;

    bool static non_zero(const Size& s) { return s.sz_ != 0; }

    Size Align(size_t alignment = 8) const {
        return {align(sz_, alignment)};
    }

private:
    size_t sz_ = 0;

    operator size_t() const { return sz_; }

    friend class AddrSpace;
    friend class Memory;
    friend class Block;
    friend std::ostream& operator<<(std::ostream& os, const Size& sz);
};

const Size Size::zero{0};
const Size Size::max{std::numeric_limits<size_t>::max()};

Size Sum(const Size& LHS, const Size& RHS) {
    return LHS + RHS;
}

std::ostream& operator<<(std::ostream& os, const Size& sz) {
    os << std::dec << sz.sz_ << " bytes";
    return os;
}
