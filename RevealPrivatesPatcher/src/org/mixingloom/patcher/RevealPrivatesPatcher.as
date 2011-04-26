/**
 * Created by IntelliJ IDEA.
 * User: James Ward <james@jamesward.org>
 * Date: 3/23/11
 * Time: 1:34 PM
 */
package org.mixingloom.patcher
{
import flash.utils.ByteArray;
import flash.utils.Endian;

import org.as3commons.bytecode.abc.ConstantPool;
import org.as3commons.bytecode.abc.IConstantPool;
import org.as3commons.bytecode.abc.LNamespace;
import org.as3commons.bytecode.abc.Multiname;
import org.as3commons.bytecode.abc.MultinameG;
import org.as3commons.bytecode.abc.QualifiedName;
import org.as3commons.bytecode.abc.enum.NamespaceKind;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.tags.DoABCTag;
import org.as3commons.bytecode.util.AbcSpec;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.ByteArrayUtils;
import org.mixingloom.utils.HexDump;
import org.mixingloom.utils.HexDump;

public class RevealPrivatesPatcher extends AbstractPatcher {

    public var className:String;

    public var propertyOrMethodName:String;

    public function RevealPrivatesPatcher(className:String, propertyOrMethodName:String)
    {
        this.className = className;
        this.propertyOrMethodName = propertyOrMethodName;
    }

    override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void {

        for each (var swfTag:SwfTag in swfContext.swfTags)
        {
            if (swfTag.type == DoABCTag.TAG_ID)
            {
                // skip the flags
                swfTag.tagBody.position = 4;

                var abcStartLocation:uint = 4;
                while (swfTag.tagBody.readByte() != 0)
                {
                    abcStartLocation++;
                }
                abcStartLocation++; // skip the string byte terminator

                var startOfConstPoolPosition:uint = abcStartLocation + 4;

                swfTag.tagBody.position = 0;

                var abcDeserializer:AbcDeserializer = new AbcDeserializer(swfTag.tagBody);
                swfTag.tagBody.position = startOfConstPoolPosition;
                var cp:IConstantPool = new ConstantPool();

                abcDeserializer.deserializeConstantPool(cp);

                // search the multinamePool for the location of the property or method
                for (var i:uint = 0; i < cp.multinamePool.length; i++) {

                    if (cp.multinamePool[i] is QualifiedName) {
                        var qn:QualifiedName = cp.multinamePool[i];
                        if ((qn.nameSpace.kind == NamespaceKind.PRIVATE_NAMESPACE) &&
                            ((qn.nameSpace.name == LNamespace.ASTERISK.name) ||
                             (qn.nameSpace.name == className)) &&
                            (qn.name == propertyOrMethodName)) {

                            var nsppos:int = cp.getNamespacePosition(qn.nameSpace);
                            var sppos:int = cp.getStringPosition(qn.name);

                            // create a bytearray the should match the constant pool private qname for the property or method
                            var origBA:ByteArray = new ByteArray();
                            origBA.writeByte(0x07); // qname
                            AbcSpec.writeU30(nsppos, origBA);
                            AbcSpec.writeU30(sppos, origBA);

                            // create a replacement bytearray that uses the public namespace for this qname
                            var repBA:ByteArray = new ByteArray();
                            repBA.writeByte(0x07); // qname
                            AbcSpec.writeU30(cp.getNamespacePosition(LNamespace.PUBLIC), repBA);
                            AbcSpec.writeU30(sppos, repBA);

                            // replace the qname in the constant pool
                            swfTag.tagBody = ByteArrayUtils.findAndReplaceFirstOccurrence(swfTag.tagBody, origBA, repBA);
                        }
                    }

                }
            }
        }

        invokeCallBack();
    }

}
}