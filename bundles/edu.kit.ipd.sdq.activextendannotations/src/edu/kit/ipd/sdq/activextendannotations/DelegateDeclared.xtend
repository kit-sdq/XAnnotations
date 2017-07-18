package edu.kit.ipd.sdq.activextendannotations

import com.google.common.annotations.Beta
import java.lang.annotation.Documented
import java.lang.annotation.ElementType
import java.lang.annotation.Target
import java.util.List
import org.eclipse.xtend.lib.annotations.Delegate
import org.eclipse.xtend.lib.annotations.DelegateProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.MemberDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableMemberDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration

/**
 * Variation of the Xtend @{@link Delegate} active annotation, that only delegates the methods that were declared in the
 * direct super interfaces of the class that uses the annotation.
 * @author Timur Saglam
 */
@Beta
@Target(#[ElementType.FIELD, ElementType.METHOD])
@Active(DelegateDeclaredProcessor)
@Documented
annotation DelegateDeclared {
	/**
	 * Optional list of interfaces that this delegate is restricted to.
	 * Defaults to the common interfaces of the context type and the annotated element.
	 */
	Class<?>[] value = #[]
}

/**
 * Annotation processor of the @{@link DelegateDeclared} active annotation.
 */
@Beta
class DelegateDeclaredProcessor implements TransformationParticipant<MutableMemberDeclaration> {

	/**
	 * Is invoked by the compiler.
	 * @param annotatedTargetElements is the mutable java representation of the annotated elements.
	 * @param context is a {@link TransformationContext} providing useful services.
	 */
	override doTransform(List<? extends MutableMemberDeclaration> elements, extension TransformationContext context) {
		val extension util = new Util(context)
		elements.forEach [ // same code as in the DelegateProcessor, just with the adapted Util class.
			if (validDelegate) {
				methodsToImplement.forEach[method|implementMethod(method)]
			}
		]
	}

	/**
	 * Utility class of the {@link DelegateDeclaredProcessor}. Extends the utility class of the
	 * {@link DelegateProcessor} of the the @{@link DelegateDeclared} active annotation.
	 */
	@Beta
	static class Util extends DelegateProcessor.Util {
		extension TransformationContext context

		/**
		 * Basic constructor, sets the transformation context.
		 */
		new(TransformationContext context) {
			super(context)
			this.context = context
		}

		/** 
		 * Filters the output of {@link Util#getDelegatedInterfaces} to only return
		 * the interfaces that are direct super interfaces of the class which uses the delegate annotation.
		 */
		override getDelegatedInterfaces(MemberDeclaration delegate) {
			super.getDelegatedInterfaces(delegate).filter [ iface |
				delegate.declaringType.newSelfTypeReference.declaredSuperTypes.toSet.contains(iface)
			].toSet // This is the only major difference to @Delegate
		}

		/**
		 * Getter for the delegates. The delegates are the members marked by the {@link DelegateDeclared}
		 * annotation.
		 */
		override getDelegates(TypeDeclaration it) { // Needs to be overridden to make the annotation work.
			declaredMembers.filter[findAnnotation(findTypeGlobally(DelegateDeclared)) !== null]
		}

		/**
		 * Getter for the listed interfaces of a member.
		 */
		override listedInterfaces(MemberDeclaration it) { // Needs to be overridden to make the annotation work.
			findAnnotation(findTypeGlobally(DelegateDeclared)).getClassArrayValue("value").toSet
		}
	}
}
