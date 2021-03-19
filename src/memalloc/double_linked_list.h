#pragma once

#include <cassert>

/*
Этот класс для связывания каких-либо классов в дважды-связанный список.

Используется через CRTP.

Пример использования можно посмотреть в tests/double_linked_list_test.cpp

Основные моменты:
1. Не поддерживает копирование (не возможно создать два элемента с одинаковыми указателями prev/next)
2. Не поддерживает перемещение
3. При удалении отлинковывается из списка

Это всё позволяет сделать работу со списками чуть более безошибочной.
*/

template<typename T>
class DlElt {
    using Self = DlElt<T>;

    template <typename Chain>
    void replace_till(Chain chain, Self& to) {
        Self* prev = prev_;
        Self* next = to.next_;
        unlink_till(to);
        Self& c = chain();
        Self& start = c.start();
        Self& end = c.end();
        if (prev != nullptr) {
            prev->next_ = &start;
            start.prev_ = prev;
        }
        if (next != nullptr) {
            next->prev_ = &end;
            end.next_ = next;
        }
    }

    void unlink_till(Self& to) {
        Self* elt = &to;
        while (elt != nullptr && elt != &to) {
            Self* next = elt->next_;
            elt->Unlink();
            elt = next;
        };
        if (elt == &to) {
            elt->Unlink();
        }
    }

    Self& start() {
        if (prev_ == nullptr) {
            return *this;
        } else {
            return prev_->start();
        }
    }

    Self& end() {
        if (next_ == nullptr) {
            return *this;
        } else {
            return next_->end();
        }
    }

    void insert_above(Self& elt) {
        next_ = elt.next_;
        if (next_ != nullptr) { next_->prev_ = this; }
        elt.next_ = this;
        prev_ = &elt;
    }

    void insert_below(Self& elt) {
        prev_ = elt.prev_;
        if (prev_ != nullptr) { prev_->next_ = this; }
        elt.prev_ = this;
        next_ = elt;
    }


public:
    DlElt() = default;
    DlElt(const DlElt&) = delete;
    DlElt(DlElt&& elt) = delete;
    DlElt& operator=(const DlElt&) = delete;
    DlElt& operator=(DlElt&& elt) = delete;
    virtual ~DlElt() { Unlink(); }

    template <typename Chain>
    void Replace(Chain chain) { replace_till(chain, *this); }

    template <typename Chain>
    void ReplaceTill(Chain chain, T& to) { replace_till(chain, to); }

    void UnlinkTill(T& to) { unlink_till(to); }

    void Unlink() {
        if (prev_ != nullptr) { prev_->next_ = next_; }
        if (next_ != nullptr) { next_->prev_ = prev_; }
        prev_ = next_ = nullptr;
    }

    void InsertAbove(T& t) { insert_above(t); }
    void InsertBelow(T& t) { insert_below(t); }

    bool HasNext() const { return next_ != nullptr; }
    bool HasPrev() const { return prev_ != nullptr; }

    T& Next() { return *dynamic_cast<T*>(next_); }
    T& Prev() { return *dynamic_cast<T*>(prev_); }
    T& Start() { return start(); }
    T& End() { return end(); }

    template<typename Handler>
    void ForAll(Handler handler) {
        Self* elt = &start();
        while(handler(*dynamic_cast<T*>(elt)) && elt->HasNext()) {
            elt = elt->next_;
        }
    }

    template<typename Handler>
    void ForAll(Handler handler) const {
        const_cast<Self*>(this)->ForAll([&handler](const T& t){
            return handler(t);
        });
    }

private:
    Self* prev_ = nullptr;
    Self* next_ = nullptr;
};
