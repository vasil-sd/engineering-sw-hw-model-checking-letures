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
public:
    DlElt() = default;
    DlElt(const DlElt&) = delete;
    DlElt(DlElt&& elt) = delete;
    DlElt& operator=(const DlElt&) = delete;
    DlElt& operator=(DlElt&& elt) = delete;
    virtual ~DlElt() { Unlink(); }

    template <typename Chain>
    void Replace(Chain chain, size_t num = 1) {
        T* prev = prev_;
        T* next = next_;
        while(--num > 0 && next != nullptr) {
            T* new_next = next->DlElt<T>::HasNext() ? &next->DlElt<T>::next() : nullptr;
            next->DlElt<T>::Unlink();
            next = new_next;
        };
        Unlink();
        T& c = chain();
        T& start = c.DlElt::start();
        T& end = c.DlElt::end();
        if (prev != nullptr) {
            prev->DlElt<T>::next_ = &start;
            start.DlElt<T>::prev_ = prev;
        }
        if (next != nullptr) {
            next->DlElt<T>::prev_ = &end;
            end.DlElt<T>::next_ = next;
        }
    }

    void Unlink() {
        if (prev_ != nullptr) { prev_->DlElt<T>::next_ = next_; }
        if (next_ != nullptr) { next_->DlElt<T>::prev_ = prev_; }
        prev_ = next_ = nullptr;
    }

    void InsertAbove(T& t) {
        next_ = t.DlElt<T>::next_;
        if (next_ != nullptr) { next_->DlElt<T>::prev_ = dynamic_cast<T*>(this); }
        t.DlElt<T>::next_ = dynamic_cast<T*>(this);
        prev_ = &t;
    }

    void InsertBelow(T& t) {
        prev_ = t.DlElt<T>::prev_;
        if (prev_ != nullptr) { prev_->DlElt<T>::next_ = dynamic_cast<T*>(this); }
        t.DlElt<T>::prev_ = dynamic_cast<T*>(this);
        next_ = &t;
    }

    bool HasNext() const { return next_ != nullptr; }

    bool HasPrev() const { return prev_ != nullptr; }

    T& next() {
        assert(HasNext());
        return *next_;
    }

    T& prev() {
        assert(HasPrev());
        return *prev_;
    }

    T& start() {
        if (prev_ == nullptr) {
            return *dynamic_cast<T*>(this);
        } else {
            return prev_->DlElt<T>::start();
        }
    }

    T& end() {
        if (next_ == nullptr) {
            return *dynamic_cast<T*>(this);
        } else {
            return next_->DlElt<T>::end();
        }
    }

    template<typename Handler>
    void ForAll(Handler handler) {
        T* t = &start();
        while(handler(*t) && t->DlElt<T>::HasNext()) {
            t = &t->next();
        }
    }

    template<typename Handler>
    void ForAll(Handler handler) const {
        const_cast<DlElt*>(this)->ForAll([&handler](const T& t){
            return handler(t);
        });
    }

private:
    T* prev_ = nullptr;
    T* next_ = nullptr;
};
