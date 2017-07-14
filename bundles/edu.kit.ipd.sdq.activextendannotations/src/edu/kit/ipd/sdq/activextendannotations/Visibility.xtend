package edu.kit.ipd.sdq.activextendannotations


/**
 * Declares desired visibility.
 */
enum Visibility {
	/**
	 * The target shall be private.
	 */
	PRIVATE,
	/**
	 * The target shall be package-private (“default visibility” in Java).
	 */
	PACKAGE,
	/**
	 * The target shall be public.
	 */
	PUBLIC,
	/**
	 * The target shall have the same visibility as its source
	 */
	AS_DECLARED
}
