/**
 * Created by IntelliJ IDEA.
 * User: James Ward <james@jamesward.org>
 * Date: 3/24/11
 * Time: 12:31 PM
 */
package org.mixingloom.patcher
{
import flash.utils.ByteArray;

import org.as3commons.bytecode.tags.DoABCTag;
import org.as3commons.bytecode.util.AbcSpec;

import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.ByteArrayUtils;

public class StringModifierPatcher extends AbstractPatcher
{
    public var originalString:String;
    public var replacementString:String;

    public function StringModifierPatcher(originalString:String, replacementString:String)
    {
        this.originalString = originalString;
        this.replacementString = replacementString;
    }

    override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void
    {
        var searchByteArray:ByteArray = new ByteArray();
        AbcSpec.writeStringInfo(originalString, searchByteArray);

        var replacementByteArray:ByteArray = new ByteArray();
        AbcSpec.writeStringInfo(replacementString, replacementByteArray);

        for each (var swfTag:SwfTag in swfContext.swfTags)
        {
            if (swfTag.type == DoABCTag.TAG_ID)
            {
                swfTag.tagBody = ByteArrayUtils.findAndReplaceFirstOccurrence(swfTag.tagBody, searchByteArray, replacementByteArray);
            }
        }

        invokeCallBack();
    }

}
}