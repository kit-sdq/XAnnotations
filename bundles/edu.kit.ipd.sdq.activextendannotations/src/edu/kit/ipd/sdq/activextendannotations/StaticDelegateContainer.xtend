package edu.kit.ipd.sdq.activextendannotations

import java.lang.annotation.Target
import java.lang.annotation.Repeatable

/**
 * Container annotation for {@link StaticDelegate}. Has no actual value
 * but is required to make {@link StaticDelegate} {@link Repeatable}.
 */
@Target(TYPE)
annotation StaticDelegateContainer {
	StaticDelegate[] value
}
