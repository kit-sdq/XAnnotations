package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.Active

@Active(StaticDelegateProcessor)
annotation StaticDelegate {
	Class<?>[] delegationTargets
}