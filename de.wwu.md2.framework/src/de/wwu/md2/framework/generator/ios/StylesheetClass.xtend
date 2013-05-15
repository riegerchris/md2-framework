package de.wwu.md2.framework.generator.ios

import de.wwu.md2.framework.mD2.Color
import de.wwu.md2.framework.mD2.HexColorDef
import de.wwu.md2.framework.mD2.NamedColorDef
import de.wwu.md2.framework.mD2.StyleAssignment
import de.wwu.md2.framework.mD2.StyleBody
import de.wwu.md2.framework.mD2.StyleDefinition
import de.wwu.md2.framework.mD2.StyleReference
import de.wwu.md2.framework.mD2.ViewGUIElement
import java.util.Date

import static de.wwu.md2.framework.generator.util.MD2GeneratorUtil.*

class StylesheetClass
{
	static int counter = 0
	
	def static createStyleM(Iterable<StyleAssignment> styles) '''
		//
		//  DefaultStyle.h
		//  TariffCalculator
		//
		//  Generated by MD2 framework on «new Date()».
		//  Copyright (c) 2012 Uni-Muenster. All rights reserved.
		//
		
		#define DefaultFont [UIFont systemFontOfSize: 17.0]
		«FOR style : styles»
			«IF style.styleBody.fontSize != 0»
				#define «getName(style.eContainer as ViewGUIElement).toFirstUpper»Font «style.styleBody.UIFontMethodCall»
			«ENDIF»
		«ENDFOR»
		
		#define DefaultTextColor [UIColor blackColor]
		«FOR style : styles»
			«IF style.styleBody.color != null»
				#define «getName(style.eContainer as ViewGUIElement).toFirstUpper»TextColor «style.styleBody.color.UIColorMethodCall»
			«ENDIF»
		«ENDFOR»'''
	
	def static createStylesheetH() '''
		//
		//  Stylesheet.h
		//
		//  Generated by MD2 framework on «new Date()».
		//  Copyright (c) 2012 Uni-Muenster. All rights reserved.
		//
		
		@interface Stylesheet : NSObject
		{
			NSString *identifier;
			
			@private
			UIFont *font;
			UIColor *textColor;
			UIColor *backgroundColor;
			UIColor *tintColor;
		}
		
		@property (retain, nonatomic) NSString *identifier;
		@property (retain, nonatomic) UIFont *font;
		@property (retain, nonatomic) UIColor *textColor;
		
		+(id) style;
		-(void) applyToObject: (id) object idenfier: (NSString *) _identifier;
		-(void) applyToObject: (id) object;
		
		@end'''
	
	def static createStylesheetM(Iterable<StyleAssignment> styles) '''
		//
		//  Stylesheet.m
		//
		//  Generated by MD2 framework on «new Date()».
		//  Copyright (c) 2012 Uni-Muenster. All rights reserved.
		//
		
		#import "Stylesheet.h"
		#import "DefaultStyle.h"
		
		@implementation Stylesheet
		
		@synthesize identifier, font, textColor;
		
		+(id) style
		{
			return [[[self class] alloc] init];
		}
		
		-(id) init
		{
			self = [super init];
			if (self)
			{
				// Default values, as specified in UIKit's documentation
				self.font = [UIFont systemFontOfSize: 17.0];
				self.textColor = [UIColor blackColor];
			}
			return self;
		}
		
		-(void) applyToObject: (id) object idenfier: (NSString *) _identifier
		{
			if ([object respondsToSelector: @selector(setFont:)])
			{
				«resetCounter»
				«FOR style : styles»
					«IF style.styleBody.fontSize != 0»
						«IF getAndIncreaseCounter > 0»else «ENDIF»if ([_identifier isEqualToString: @"«getName(style.eContainer as ViewGUIElement).toFirstLower»"])
							[object setFont: «getName(style.eContainer as ViewGUIElement).toFirstUpper»Font];
					«ENDIF»
				«ENDFOR»
				«IF counter > 0»else«ENDIF»
					[object setFont: DefaultFont];
			}
			
			if ([object respondsToSelector: @selector(setTextColor:)])
			{
				«resetCounter»
				«FOR style : styles»
					«IF style.styleBody.color != null»
						«IF getAndIncreaseCounter > 0»else «ENDIF»if ([_identifier isEqualToString: @"«getName(style.eContainer as ViewGUIElement).toFirstLower»"])
							[object setTextColor: «getName(style.eContainer as ViewGUIElement).toFirstUpper»TextColor];
					«ENDIF»
				«ENDFOR»
				«IF counter > 0»else«ENDIF»
					[object setTextColor: DefaultTextColor];
			}
		}
		
		-(void) applyToObject: (id) object
		{
			if ([object respondsToSelector: @selector(setFont:)])
			{
				[object setFont: self.font];
			}
			if ([object respondsToSelector: @selector(setTextColor:)])
			{
				[object setTextColor: self.textColor];
			}
		}
		
		@end'''
	
	/**
	 * Returns the style body of a style assignment that can be a reference or a direct definition of the body
	 */
	def private static getStyleBody(StyleAssignment style)
	{
		switch style
		{
			StyleDefinition: style.definition
			StyleReference: style.reference.body
		}
	}
	
	/**
	 * Converts the hex color into its rgb equivalent and builds the according string to specify the color
	 * in objective c.
	 */
	def private static getUIColorMethodCall(Color color)
	{
		switch color
		{
			HexColorDef:
			{
				val hex = color.color
				var float alpha
				var float red
				var float green
				var float blue
				
				if(hex.length == 7)
				{
					// no alpha channel specified
					alpha = 1f
					red = Integer::valueOf(hex.substring(1, 3), 16).floatValue / 255f
					green = Integer::valueOf(hex.substring(3, 5), 16).floatValue / 255f
					blue = Integer::valueOf(hex.substring(5, 7), 16).floatValue / 255f
				}
				else if(hex.length == 9)
				{
					// first two digits represent alpha channel
					alpha = Integer::valueOf(hex.substring(1, 3), 16).floatValue / 255f
					red = Integer::valueOf(hex.substring(3, 5), 16).floatValue / 255f
					green = Integer::valueOf(hex.substring(5, 7), 16).floatValue / 255f
					blue = Integer::valueOf(hex.substring(7, 9), 16).floatValue / 255f
				}
				
				'''[UIColor colorWithRed: «red» green: «green» blue: «blue» alpha: «alpha»]'''
			}
			NamedColorDef:
			{
				// something went wrong -> preprocessing replaces all named colors by its hex values
				System::err.println("Something went wrong during preprocessing! Found a named color definition which actually should " +
					"have been replaced by its hex value equivalent."
				)
			}
		}
	}
	
	def static getUIFontMethodCall (StyleBody style)
	{
		var String bold
		var String italic
		
		if (style.bold)
			bold = "-Bold"
		else if (style.italic)
		{
			if (!style.bold)
				italic = "-Italic"
			else
				italic = "Italic"
		}
		if (bold != null || italic != null)
			'''[UIFont fontWithName: @"Helvetica«bold»«italic»" size: «style.fontSize».0]'''
		else
			'''[UIFont systemFontOfSize: «style.fontSize».0]'''
	}
	
	def private static getAndIncreaseCounter()
	{
		counter = counter + 1
		counter - 1
	}
	
	def private static resetCounter()
	{
		counter = 0
		return
	}
}
