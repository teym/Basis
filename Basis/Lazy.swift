//
//  Lazy.swift
//  Basis
//
//  Created by Robert Widmann on 9/7/14.
//  Copyright (c) 2014 TypeLift. All rights reserved.
//  Released under the MIT license.
//

internal enum LazyState<A> {
	case Eventually(() -> A)
	case Now(Box<A>)
}

/// @autoclosure as a monad.
public struct Lazy<A> {
	let state : STRef<(), LazyState<A>>
	
	init(_ state : STRef<(), LazyState<A>>) {
		self.state = state
	}
}

public func delay<A>(f : () -> A) -> Lazy<A> {
	return Lazy(newSTRef(.Eventually(f)).runST())
}

public func force<A>(l : Lazy<A>) -> A {
	return (modifySTRef(l.state)(f: { st in
		switch st {
			case .Eventually(let f):
				return .Now(Box(f()))
			default:
				return st
		}
	}) >>- { st in
		switch readSTRef(st).runST() {
			case .Now(let bx):
				return ST<(), A>.pure(bx.unBox())
			default:
				fatalError("Cannot ")
		}
	}).runST()
}

extension Lazy : Functor {
	typealias B = Any
	typealias FB = Lazy<B>
	
	public static func fmap<B>(f: A -> B) -> Lazy<A> -> Lazy<B> {
		return { st in
			switch readSTRef(st.state).runST() {
				case .Eventually(let d):
					return delay({ f(d()) })
				case .Now(let bx):
					return self.pure(f(bx.unBox()))
			}
		}
	}
}

public func <%><A, B>(f: A -> B, st: Lazy<A>) -> Lazy<B> {
	return Lazy.fmap(f)(st)
}

public func <%<A, B>(x : A, l : Lazy<B>) -> Lazy<A> {
	return Lazy.fmap(const(x))(l)
}

extension Lazy : Pointed {
	public static func pure<A>(a: A) -> Lazy<A> {
		return Lazy<A>(newSTRef(.Now(Box(a))).runST())
	}
}

extension Lazy : Applicative {
	typealias FAB = Lazy<A -> B>
	
	public static func ap<A, B>(stfn: Lazy<A -> B>) -> Lazy<A> -> Lazy<B> {
		return { st in
			switch readSTRef(stfn.state).runST() {
				case .Eventually(let d):
					return delay({ d()(force(st)) })
				case .Now(let bx):
					return Lazy<A>.fmap(bx.unBox())(st)
			}
		}
	}
}

public func <*><A, B>(stfn: Lazy<A -> B>, st: Lazy<A>) -> Lazy<B> {
	return Lazy<A>.ap(stfn)(st)
}

public func *><A, B>(a : Lazy<A>, b : Lazy<B>) -> Lazy<B> {
	return const(id) <%> a <*> b
}

public func <*<A, B>(a : Lazy<A>, b : Lazy<B>) -> Lazy<A> {
	return const <%> a <*> b
}

extension Lazy : ApplicativeOps {
	typealias C = Any
	typealias FC = Lazy<C>
	typealias D = Any
	typealias FD = Lazy<D>

	public static func liftA<B>(f : A -> B) -> Lazy<A> -> Lazy<B> {
		return { a in Lazy<A -> B>.pure(f) <*> a }
	}

	public static func liftA2<B, C>(f : A -> B -> C) -> Lazy<A> -> Lazy<B> -> Lazy<C> {
		return { a in { b in f <%> a <*> b  } }
	}

	public static func liftA3<B, C, D>(f : A -> B -> C -> D) -> Lazy<A> -> Lazy<B> -> Lazy<C> -> Lazy<D> {
		return { a in { b in { c in f <%> a <*> b <*> c } } }
	}
}

extension Lazy : Monad {
	public func bind<B>(f: A -> Lazy<B>) -> Lazy<B> {
		return f(force(self))
	}
}

public func >>-<A, B>(x : Lazy<A>, f : A -> Lazy<B>) -> Lazy<B> {
	return x.bind(f)
}

public func >><A, B>(x : Lazy<A>, y : Lazy<B>) -> Lazy<B> {
	return x.bind({ (_) in
		return y
	})
}

extension Lazy : MonadOps {
	typealias MLA = Lazy<[A]>
	typealias MLB = Lazy<[B]>
	typealias MU = Lazy<()>

	public static func mapM<B>(f : A -> Lazy<B>) -> [A] -> Lazy<[B]> {
		return { xs in Lazy<B>.sequence(map(f)(xs)) }
	}

	public static func mapM_<B>(f : A -> Lazy<B>) -> [A] -> Lazy<()> {
		return { xs in Lazy<B>.sequence_(map(f)(xs)) }
	}

	public static func forM<B>(xs : [A]) -> (A -> Lazy<B>) -> Lazy<[B]> {
		return flip(Lazy.mapM)(xs)
	}

	public static func forM_<B>(xs : [A]) -> (A -> Lazy<B>) -> Lazy<()> {
		return flip(Lazy.mapM_)(xs)
	}

	public static func sequence(ls : [Lazy<A>]) -> Lazy<[A]> {
		return foldr({ m, m2 in m >>- { x in m2 >>- { xs in Lazy<[A]>.pure(cons(x)(xs)) } } })(Lazy<[A]>.pure([]))(ls)
	}

	public static func sequence_(ls : [Lazy<A>]) -> Lazy<()> {
		return foldr(>>)(Lazy<()>.pure(()))(ls)
	}
}

public func -<<<A, B>(f : A -> Lazy<B>, xs : Lazy<A>) -> Lazy<B> {
	return xs.bind(f)
}

public func >-><A, B, C>(f : A -> Lazy<B>, g : B -> Lazy<C>) -> A -> Lazy<C> {
	return { x in f(x) >>- g }
}

public func <-<<A, B, C>(g : B -> Lazy<C>, f : A -> Lazy<B>) -> A -> Lazy<C> {
	return { x in f(x) >>- g }
}
