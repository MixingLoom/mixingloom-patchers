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
import org.as3commons.bytecode.abc.enum.NamespaceKind;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.util.AbcSpec;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.ByteArrayUtils;

public class RevealPrivatesPatcher extends AbstractPatcher {

    public var className:String;

    public var tagName:String;

    public var propertyOrMethodName:String;

    public function RevealPrivatesPatcher(tagName:String, className:String, propertyOrMethodName:String)
    {
        this.tagName = tagName;
        this.className = className;
        this.propertyOrMethodName = propertyOrMethodName;
    }

    override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void {

        for each (var swfTag:SwfTag in swfContext.swfTags)
        {
            if (((swfTag.name == tagName) || (tagName == null)) && (swfTag.type == 82))
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
                
                var ons:LNamespace = new LNamespace(NamespaceKind.PRIVATE_NAMESPACE, className);
                var onsp:int = -1;

                // using our own find here because the equals used in cp.getNamespacePosition doesn't like private namespaces
                for (var i:uint = 0; i < cp.namespacePool.length; i++)
                {
                    if ((cp.namespacePool[i].kind == ons.kind) && (cp.namespacePool[i].name == ons.name))
                    {
                        onsp = i;
                        break;
                    }
                }

                var propOrMethNamePos:int = cp.getStringPosition(propertyOrMethodName);

                if ((onsp == -1) || (propOrMethNamePos == -1))
                {
                    // didn't find it
                    continue;
                }

                var origBA:ByteArray = new ByteArray();
                origBA.writeByte(0x07); // qname
                AbcSpec.writeU30(onsp, origBA);
                AbcSpec.writeU30(propOrMethNamePos, origBA);

                var repBA:ByteArray = new ByteArray();
                repBA.writeByte(0x07);
                AbcSpec.writeU30(cp.getNamespacePosition(LNamespace.PUBLIC), repBA);
                AbcSpec.writeU30(propOrMethNamePos, repBA);

                swfTag.tagBody = ByteArrayUtils.findAndReplaceFirstOccurrence(swfTag.tagBody, origBA, repBA);

                // update the recordHeader
                swfTag.recordHeader = new ByteArray();
                swfTag.recordHeader.endian = Endian.LITTLE_ENDIAN;
                swfTag.recordHeader.writeByte(0xbf);
                swfTag.recordHeader.writeByte(0x14);
                swfTag.recordHeader.writeInt(swfTag.tagBody.length);
                
                swfTag.modified = true;
            }
        }

        invokeCallBack();
    }

}
}