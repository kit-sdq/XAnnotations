package edu.kit.ipd.sdq.activextendannotations

import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationParticipant
import java.util.List
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableTypeDeclaration
import org.eclipse.xtend.lib.macro.ValidationParticipant
import org.eclipse.xtend.lib.macro.ValidationContext
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.Visibility

/**
 * Marks a class as a utility class. This makes the class `final`, adds a
 * private, parameterless constructor and does not allow any other
 * constructors. Additionally adds errors to instance methods, instance fields
 * and non-final static fields as these do not belong in a utility class and
 * were most likely added by accident.
 * 
 * Despite these changes to the generated source, this annotation is also meant
 * as a more declarative way of defining utility classes.
 */
@Target(TYPE)
@Active(UtilityProcessor)
annotation Utility {
}

class UtilityProcessor implements TransformationParticipant<MutableTypeDeclaration>, ValidationParticipant<MutableTypeDeclaration> {

	override doTransform(List<? extends MutableTypeDeclaration> annotatedTargetElements,
		extension TransformationContext context) {
		for (annotatedType : annotatedTargetElements) {
			if (annotatedType instanceof MutableClassDeclaration) {
				annotatedType.final = true
				val privateParameterlessConstructors = annotatedType.declaredConstructors.filter [
					visibility == Visibility.PRIVATE && parameters.length == 0
				]
				if (privateParameterlessConstructors.length == 0) {
					annotatedType.addConstructor [
						visibility = Visibility.PRIVATE
						body = ''''''
					]
				}
			}
		}
	}

	override doValidate(List<? extends MutableTypeDeclaration> annotatedTargetElements,
		extension ValidationContext context) {
		for (annotatedType : annotatedTargetElements) {
			if (annotatedType instanceof MutableClassDeclaration) {
				annotatedType.declaredConstructors.filter[visibility != Visibility.PRIVATE || parameters.length > 0].
					forEach [
						addError("A Utility class may not have a constructor.")
					]
				annotatedType.declaredMethods.filter[!static].forEach [
					addError("A Utility class may only have static methods.")
				]
				annotatedType.declaredFields.filter[!static].forEach [
					addError("A Utility class must not have instance fields, as it is never constructed")
				]
				annotatedType.declaredFields.filter[static].filter[!final].forEach [
					addError("A Utility class may only have final static fields, as it must not store state.")
				]
			} else {
				annotatedType.addError("Only classes can be declared as Utility")
			}
		}
	}
}
