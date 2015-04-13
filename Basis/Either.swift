//
//  Either.swift
//  Basis
//
//  Created by Robert Widmann on 9/9/14.
//  Copyright (c) 2014 TypeLift. All rights reserved.
//  Released under the MIT license.
//

public enum EitherD<A, B> {
	case Left(Box<A>)
	case Right(Box<B>)
}

/// Either represents a computation that either produces a result (left) or fails with an error
/// (right).
public struct Either<L, R>  {
	let lVal : L?
	let rVal : R?
	
	init(left : L) {
		self.lVal = left
        self.rVal = nil
	}
	
	init(right : R) {
        self.lVal = nil
		self.rVal = right
	}

	public static func left(x : L) -> Either<L, R> {
		return Either(left: x)
	}
	
	public static func right(x : R) -> Either<L, R> {
		return Either(right: x)
	}
	
	public static func left(x : Box<L>) -> Either<L, R> {
		return Either(left: x.unBox())
	}
	
	public static func right(x : Box<R>) -> Either<L, R> {
		return Either(right: x.unBox())
	}
	
	public func match() -> EitherD<L, R> {
		if lVal != nil {
			return .Left(Box(lVal!))
		}
		return .Right(Box(rVal!))
	}
}

/// Case analysis.  If the Either is Left, applies the left function to that value.  Else, if the 
/// either is right, applies the right function to that value.
public func either<A, B, C>(left : A -> C) -> (B -> C) -> Either<A, B> -> C {
	return { right in { e in
		switch e.match() {
			case .Left(let x):
				return left(x.unBox())
			case .Right(let y):
				return right(y.unBox())
		}
	} }
}

/// Extracts all eithers that have left values in order.
public func lefts<A, B>(l : [Either<A, B>]) -> [A] {
	return concatMap({
		switch $0.match() {
			case .Left(let a):
				return [a.unBox()]
			default:
				return []
		}
	})(l)
}

/// Extracts all eithers that have right values in order.
public func rights<A, B>(l : [Either<A, B>]) -> [B] {
	return concatMap({
		switch $0.match() {
			case .Right(let b):
				return [b.unBox()]
			default:
				return []
		}
	})(l)
}

/// Returns whether an either holds a right value.
public func isRight<A, B>(e : Either<A, B>) -> Bool {
	switch e.match() {
		case .Right(_):
			return true
		default:
			return false
	}
}

/// Returns whether an either holds a left value.
public func isLeft<A, B>(e : Either<A, B>) -> Bool {
	switch e.match() {
		case .Left(_):
			return true
		default:
			return false
	}
}

/// Maps an either onto a Result given a function from left to an NSError.
public func asResult<A, B>(e : Either<A, B>) -> (A -> NSError) -> Result<B> {
	return { f in either({ e in Result.error(f(e)) })({ v in Result.value(v) })(e) }
}

// MARK: Equatable

public func == <A : Equatable, B : Equatable>(lhs: Either<A, B>, rhs: Either<A, B>) -> Bool {
	switch (lhs.match(), rhs.match()) {
		case let (.Right(x), .Right(y)) where x.unBox() == y.unBox():
			return true
		case let (.Left(x), .Left(y)) where x.unBox() == y.unBox():
			return true
		default:
			return false
	}
}

public func != <A : Equatable, B : Equatable>(lhs: Either<A, B>, rhs: Either<A, B>) -> Bool {
	return !(lhs == rhs)
}

// MARK: Functor

extension Either : Functor {
	typealias A = R
	typealias B = Any
	typealias FB = Either<L, B>

	public static func fmap<C>(f : R -> C) -> Either<L, R> -> Either<L, C> {
		return { 
			switch $0.match() {
				case .Left(let b):
					return Either<L, C>.left(b)
				case .Right(let b):
					return Either<L, C>.right(f(b.unBox()))
			}
		}
	}

}

public func <%> <A, B, C>(f : B -> C, either : Either<A, B>) -> Either<A, C> {
	return Either.fmap(f)(either)
}

public func <% <A, B, C>(x : B, either : Either<A, C>) -> Either<A, B> {
	return Either.fmap(const(x))(either)
}

extension Either : Pointed {
	public static func pure(x : R) -> Either<L, R> {
		return Either<L, R>.right(x)
	}
}

extension Either : Applicative {
	typealias FAB = Either<L, R -> C>
	
	public static func ap<C>(f : Either<L, R -> C>) -> Either<L, R> -> Either<L, C> {
		return { e in 
			switch f.match() {
				case .Left(let e):
					return Either<L, C>.left(e)
				case .Right(let f):
					return Either<L, R>.fmap(f.unBox())(e)
			}
		}
	}
}

public func <*> <A, B, C>(f : Either<A, B -> C> , r : Either<A, B>) ->  Either<A, C> {
	return Either<A, B>.ap(f)(r)
}

public func *> <A, B, C>(a : Either<A, B>, b : Either<A, C>) -> Either<A, C> {
	return const(id) <%> a <*> b
}

public func <* <A, B, C>(a : Either<A, B>, b : Either<A, C>) -> Either<A, B> {
	return const <%> a <*> b
}

extension Either : ApplicativeOps {
	typealias C = Any
	typealias FC = Either<L, C>
	typealias D = Any
	typealias FD = Either<L, D>

	public static func liftA<B>(f : A -> B) -> Either<L, A> -> Either<L, B> {
		return { a in Either<L, A -> B>.pure(f) <*> a }
	}

	public static func liftA2<B, C>(f : A -> B -> C) -> Either<L, A> -> Either<L, B> -> Either<L, C> {
		return { a in { b in f <%> a <*> b  } }
	}

	public static func liftA3<B, C, D>(f : A -> B -> C -> D) -> Either<L, A> -> Either<L, B> -> Either<L, C> -> Either<L, D> {
		return { a in { b in { c in f <%> a <*> b <*> c } } }
	}
}

extension Either : Monad {
	public func bind<B>(f : A -> Either<L, B>) -> Either<L, B> {
		switch self.match() {
			case .Left(let l):
				return Either<L, B>.left(l)
			case .Right(let r):
				return f(r.unBox())
		}
	}
}

public func >>- <L, A, B>(xs : Either<L, A>, f : A -> Either<L, B>) -> Either<L, B> {
	return xs.bind(f)
}

public func >> <A, B, C>(x : Either<A, B>, y : Either<A, C>) -> Either<A, C> {
	return x >>- { (_) in
		return y
	}
}

extension Either : MonadOps {
	typealias MLA = Either<L, [A]>
	typealias MLB = Either<L, [B]>
	typealias MU = Either<L, ()>

	public static func mapM<B>(f : A -> Either<L, B>) -> [A] -> Either<L, [B]> {
		return { xs in Either<L, B>.sequence(map(f)(xs)) }
	}

	public static func mapM_<B>(f : A -> Either<L, B>) -> [A] -> Either<L, ()> {
		return { xs in Either<L, B>.sequence_(map(f)(xs)) }
	}

	public static func forM<B>(xs : [A]) -> (A -> Either<L, B>) -> Either<L, [B]> {
		return flip(Either.mapM)(xs)
	}

	public static func forM_<B>(xs : [A]) -> (A -> Either<L, B>) -> Either<L, ()> {
		return flip(Either.mapM_)(xs)
	}

	public static func sequence(ls : [Either<L, A>]) -> Either<L, [A]> {
		return foldr({ m, m2 in m >>- { x in m2 >>- { xs in Either<L, [A]>.pure(cons(x)(xs)) } } })(Either<L, [A]>.pure([]))(ls)
	}

	public static func sequence_(ls : [Either<L, A>]) -> Either<L, ()> {
		return foldr(>>)(Either<L, ()>.pure(()))(ls)
	}
}

public func -<< <L, A, B>(f : A -> Either<L, B>, xs : Either<L, A>) -> Either<L, B> {
	return xs.bind(f)
}

public func >-> <L, A, B, C>(f : A -> Either<L, B>, g : B -> Either<L, C>) -> A -> Either<L, C> {
	return { x in f(x) >>- g }
}

public func <-< <L, A, B, C>(g : B -> Either<L, C>, f : A -> Either<L, B>) -> A -> Either<L, C> {
	return { x in f(x) >>- g }
}

extension Either : MonadFix {
	public static func mfix(f : R -> Either<L, R>) -> Either<L, R> {
		func fromRight(e : Either<L, R>) -> R {
			switch e.match() {
				case .Right(let br):
					return br.unBox()
				case .Left(let bl):
					return error("Cannot take fixpoint of left Either")
			}
		}
		return f(fromRight(Either.mfix(f)))
	}
}
