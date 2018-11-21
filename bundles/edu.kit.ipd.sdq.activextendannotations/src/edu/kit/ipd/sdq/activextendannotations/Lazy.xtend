package edu.kit.ipd.sdq.activextendannotations

import java.lang.annotation.ElementType
import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.AbstractFieldProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration

import static extension edu.kit.ipd.sdq.activextendannotations.VisibilityExtension.toXtendVisibility
import org.eclipse.xtend.lib.macro.declaration.FieldDeclaration

/**
 * Lazily initializes a field. A field annotated with {@code @Lazy} will get a
 * getter that will, when called for the first time in the field’s
 * lifetime, execute the field’s initializer. Subsequent calls will use the 
 * computed value.
 * 
 * The generated getter will have the visibility defined in the annotation’s
 * value, which defaults to {@link Visibility.PUBLIC}. The added helpers will
 * have the visibility that’s defined on the annotated field, which allows
 * to make them visible to subtypes.
 * 
 * The initializer is guaranteed to be called at the first access and only
 * once. Should it throw a runtime exception, that exception will be thrown at
 * first access. In that case, the field will have its 
 * {@link http://docs.oracle.com/javase/tutorial/java/nutsandbolts/datatypes.html default value}.
 * 
 * The variable check and call to the initializer is <em>not synchronized</em> by
 * default, which means that the implementation is not thread safe and may call the
 * initialiser multiple times when called from different threads. If you need thread
 * safety, set {@code synchronizeInitialization} to {@code true}.
 * 
 * The field itself will be renamed to have an underscore ({@code field} -> 
 * {@code _field}). It should <em>never</em> be reassigned by hand, as that 
 * would likely break the contract of this annotation.
 * 
 * To know whether the annotated field was already initialized, 
 * {@code _field_isInitialised} can be read. Once again, the field should
 * <em>never</em> be assigned by hand as that would break this annotation’s
 * contract.
 * 
 * This annotation was inspired by 
 * {@link https://github.com/eclipse/xtext-xtend/blob/master/org.eclipse.xtend.examples/projects/xtend-annotation-examples/src/lazy/Lazy.xtend
 * The Lazy annotation from Xtext’s active annotations example}
 * 
 * @author Joshua Gleitze
 */
@Target(ElementType.FIELD)
@Active(LazyProcessor)
annotation Lazy {
	Visibility value = Visibility.PUBLIC
	boolean synchronizeInitialization = false
}

class LazyProcessor extends AbstractFieldProcessor {

	override doTransform(MutableFieldDeclaration field, extension TransformationContext context) {
		if (field.initializer === null) {
			field.addError("A lazy field must have an initializer.")
			return
		}

		if (field.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.PUBLIC) {
			field.addWarning("A lazy field should not be public, as this makes internals visible to the outside.")
		}

		val setter = field.declaringType.findDeclaredMethod('set' + field.simpleName.toFirstUpper, field.type)
		if (setter !== null) {
			setter.addError("A lazy field cannot have a setter.")
		}

		val annotation = field.findAnnotation(Lazy.findTypeGlobally)
		val getterVisibility = Visibility.valueOf(annotation.getEnumValue('value').simpleName).
			toXtendVisibility(field.visibility)
		val synchronizeAccess = annotation.getBooleanValue('synchronizeInitialization')

		val isInited = field.declaringType.addField('''_«field.simpleName»_isInitialised''') [
			type = context.primitiveBoolean
			initializer = '''false'''
			visibility = field.visibility
			static = field.static
			volatile = field.volatile || synchronizeAccess
			primarySourceElement = field
		]

		val initializer = field.declaringType.addMethod('''_«field.simpleName»_initialise''') [
			returnType = field.type
			static = field.static
			visibility = field.visibility
			body = field.initializer
			primarySourceElement = field
		]

		val intialization = [| '''
			try {
				«field.simpleName» = «initializer.simpleName»();
			} finally {
				«isInited.simpleName» = true;
			}
		''' ]
		field.declaringType.addMethod('get' + field.simpleName.toFirstUpper) [
			returnType = initializer.returnType
			static = field.static
			visibility = getterVisibility
			body = '''
				if (!«isInited.simpleName») {
					«IF synchronizeAccess»
						synchronized(«field.initSynchronizationTarget») {
							if (!«isInited.simpleName») {
								«intialization.apply»
							}
						}
					«ELSE»
						«intialization.apply»
					«ENDIF»
				}
				return «field.simpleName»;
			'''
			primarySourceElement = field
		]

		field => [
			markAsRead()
			simpleName = '''_«field.simpleName»'''
			final = false
			volatile = field.volatile || synchronizeAccess		
		]
	}
	
	def private static getInitSynchronizationTarget(FieldDeclaration field) {
		if (field.isStatic) {
			'''«field.declaringType.simpleName».class'''
		} else {
			'this'
		}
	} 
}
