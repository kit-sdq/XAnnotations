package edu.kit.ipd.sdq.activextendannotations

import com.google.common.annotations.Beta
import com.google.common.annotations.GwtCompatible
import java.lang.annotation.ElementType
import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.Active
import java.lang.annotation.Documented
import org.eclipse.xtend.lib.annotations.DelegateProcessor
import org.eclipse.xtend.lib.macro.declaration.MutableMemberDeclaration
import org.eclipse.xtend.lib.macro.TransformationContext
import java.util.List
import org.eclipse.xtend.lib.macro.declaration.MemberDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration
import org.eclipse.xtend.lib.annotations.Delegate
import java.util.Collection
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.TransformationParticipant

/**
 * Works exactly like the {@link Delegate} annotation, but accepts an optional list
 * of interfaces to which no delegation methods will be generated.
 * @author Heiko Klare
 */
@Beta
@GwtCompatible
@Target(ElementType.FIELD, ElementType.METHOD)
@Active(DelegateExceptProcessor)
@Documented
annotation DelegateExcept {
	/**
	 * Optional list of interfaces whose methods shall not be delegated.
	 */
	Class<?>[] value = #[]
}

@Beta
class DelegateExceptProcessor implements TransformationParticipant<MutableMemberDeclaration> {
	override doTransform(List<? extends MutableMemberDeclaration> elements, extension TransformationContext context) {
		val extension util = new DelegateExceptProcessor.Util(context)
		elements.forEach [
			if (validDelegate) {
				val relevantMethods = filterMethodsFromExceptionalInterfaces(methodsToImplement);
				relevantMethods.forEach[method|implementMethod(method)]
			}
		]
	}

	@Beta
	static class Util extends org.eclipse.xtend.lib.annotations.DelegateProcessor.Util {
		extension TransformationContext context

		new(TransformationContext context) {
			super(context)
			this.context = context;
		}

		def filterMethodsFromExceptionalInterfaces(MemberDeclaration member, Collection<ResolvedMethod> methods) {
			val exceptionalInterfaceNames = member.findAnnotation(findTypeGlobally(DelegateExcept)).
				getClassArrayValue("value").map[name];
			return methods.filter [ method |
				!exceptionalInterfaceNames.exists [ name |
					method.declaration.declaringType.qualifiedName.equals(name)
				]
			];
		}

		/**
		 * Getter for the delegates. The delegates are the members marked by the {@link DelegateDeclared}
		 * annotation.
		 */
		override getDelegates(TypeDeclaration it) { // Needs to be overridden to make the annotation work.
			declaredMembers.filter[findAnnotation(findTypeGlobally(DelegateExcept)) !== null]
		}

		/**
		 * Getter for the listed interfaces of a member.
		 */
		override listedInterfaces(MemberDeclaration it) { // Needs to be overridden to make the annotation work.
			#{};
		}
	}
}
