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

final class VisibilityExtension {
	private new() {
	}

	/**
	 * Converts a {@link Visibility} instance to Xtend’s
	 * {@link org.eclipse.xtend.lib.macro.declaration.Visibility}. Uses the
	 * provided `defaultVisibility` if the instance is 
	 * {@link Visibility.AS_DECLARED}.
	 * 
	 * @param visibility The visibility to convert.
	 * @param defaultVisibility The visibility to use if `visibility` is
	 * {@link Visibility.AS_DECLARED}
	 */
	def static toXtendVisibility(Visibility visibility,
		org.eclipse.xtend.lib.macro.declaration.Visibility defaultVisibility) {
		switch (visibility) {
			case PRIVATE:
				org.eclipse.xtend.lib.macro.declaration.Visibility.PRIVATE
			case PACKAGE: {
				org.eclipse.xtend.lib.macro.declaration.Visibility.DEFAULT
			}
			case PUBLIC: {
				org.eclipse.xtend.lib.macro.declaration.Visibility.PUBLIC
			}
			case AS_DECLARED: {
				defaultVisibility
			}
		}
	}
}
