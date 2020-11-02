#pragma once

#include "size.h"

#include <cassert>
#include <iostream>

class AddrSpace {
public:
    AddrSpace(void* lowest, void* highest)
        : lowest_{lowest}
        , highest_{highest}
    {
        assert(highest > lowest);
        assert(lowest != nullptr);
    }
    AddrSpace() = delete;
    AddrSpace(const AddrSpace&) = default;
    AddrSpace(AddrSpace&&) = default;
    AddrSpace& operator=(const AddrSpace&) = default;
    AddrSpace& operator=(AddrSpace&&) = default;
    ~AddrSpace() = default;

    class Address {
    private:
        Address(const void* addr) {
            assert(addr != nullptr);
            addr_ = addr;
        }
    public:
        ~Address() = default;
        Address(const Address&) = default;
        Address(Address&& a) {
            addr_ = a.addr_;
        }
        Address& operator=(const Address&) = default;
        Address& operator=(Address&& a) {
            addr_ = a.addr_;
        }
        bool IsNull() const {
            return addr_ == nullptr;
        }
        Address operator+(const Size& s) const {
            if (IsNull()) {
                return {*this};
            } else {
                const void* ptr = reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(addr_) + static_cast<size_t>(s));
                Address a{ptr};
                return a;
            }
        }
        bool operator==(const Address& RHS) const {
            return  addr_ == RHS.addr_;
        }
        bool operator!=(const Address& RHS) const {
            return  addr_ != RHS.addr_;
        }
        bool operator>=(const Address& RHS) const {
            return  addr_ >= RHS.addr_;
        }
        bool operator<=(const Address& RHS) const {
            return  addr_ <= RHS.addr_;
        }
        bool operator>(const Address& RHS) const {
            return  addr_ > RHS.addr_;
        }
        bool operator<(const Address& RHS) const {
            return  addr_ < RHS.addr_;
        }
    private:
        Address() = default;
        const void* addr_ = nullptr;
        friend class AddrSpace;
        friend class Block;
        friend std::ostream& operator<<(std::ostream& os, const Address& addr);
    };

    Address null() const {
        return {};
    }

    Address address(void* addr) const {
        assert(addr>=lowest_);
        assert(addr<=highest_);
        return {addr};
    }

    Address lowest() const {
        return {lowest_};
    }

    Address highest() const {
        return {highest_};
    }

    static Address Sum(const Address& LHS, const Size& RHS) {
        return LHS + RHS;
    }

    static Size Distance(const Address& Lower, const Address& Upper) {
        assert(not_null(Lower));
        assert(not_null(Upper));
        assert(Lower <= Upper);
        auto lower = reinterpret_cast<uintptr_t>(Lower.addr_);
        auto upper = reinterpret_cast<uintptr_t>(Upper.addr_);
        return {static_cast<size_t>(upper - lower)};
    }

    static bool not_null(const Address& A) {
        return !A.IsNull();
    }

private:
    const void* lowest_;
    const void* highest_;
};

std::ostream& operator<<(std::ostream& os, const AddrSpace::Address& addr) {
    os << std::hex << addr.addr_;
    return os;
}
