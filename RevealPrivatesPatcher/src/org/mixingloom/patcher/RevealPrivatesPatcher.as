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

import org.as3commons.bytecode.abc.AbcFile;
import org.as3commons.bytecode.abc.BaseMultiname;
import org.as3commons.bytecode.abc.ConstantPool;
import org.as3commons.bytecode.abc.IConstantPool;
import org.as3commons.bytecode.abc.InstanceInfo;
import org.as3commons.bytecode.abc.LNamespace;
import org.as3commons.bytecode.abc.MethodBody;
import org.as3commons.bytecode.abc.MethodInfo;
import org.as3commons.bytecode.abc.Multiname;
import org.as3commons.bytecode.abc.QualifiedName;
import org.as3commons.bytecode.abc.TraitInfo;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.io.AbcSerializer;
import org.as3commons.bytecode.io.MethodBodyExtractionKind;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.ByteArrayUtils;
import org.mixingloom.utils.HexDump;

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
                var needsModification:Boolean = false;

                // skip the flags
                swfTag.tagBody.position = 4;

                var abcStartLocation:uint = 4;
                while (swfTag.tagBody.readByte() != 0)
                {
                    abcStartLocation++;
                }
                abcStartLocation++; // skip the string byte terminator

                var startOfConstPoolPosition:uint = abcStartLocation + 4;

                //trace("abcStartLocation = " + abcStartLocation);

                //trace(swfTag.name);
                //trace(swfTag.type);
                //trace(HexDump.dumpHex(swfTag.tagBody));

                swfTag.tagBody.position = 0;

                var abcDeserializer:AbcDeserializer = new AbcDeserializer(swfTag.tagBody);
                swfTag.tagBody.position = startOfConstPoolPosition;
                var cp:IConstantPool = new ConstantPool();

                abcDeserializer.deserializeConstantPool(cp);
                var endOfConstPoolPosition:uint = swfTag.tagBody.position;

                trace(startOfConstPoolPosition + " to " + endOfConstPoolPosition);

                var multiname:QualifiedName = cp.multinamePool[cp.getMultinamePositionByName(propertyOrMethodName)];

                if (multiname != null) {
                    trace('found ' + propertyOrMethodName);
                    trace(multiname);

                    // create a bytearray for the original serialized multiname
                    var mnAbcSerializer:AbcSerializer = new AbcSerializer();
                    var nCP:IConstantPool = new ConstantPool();
                    nCP.addMultiname(multiname);
                    //nCP.addItemToPool(ConstantKind.)
                    var nCPBA:ByteArray = new ByteArray();
                    nCPBA.endian = Endian.LITTLE_ENDIAN;
                    mnAbcSerializer.serializeConstantPool(nCP, nCPBA);

                    trace(HexDump.dumpHex(nCPBA));

                    trace('location in CP ' + ByteArrayUtils.indexOf(swfTag.tagBody, nCPBA));

                    // create a replacement bytearray from the new serialized multiname

                    // replace the original section with the new section

                    //multiname.nameSpace = LNamespace.PUBLIC;
                    needsModification = true;
                }


                // if we didn't modify anything, then just continue
                if (!needsModification) {
                    continue;
                }

                /*trace('startOfConstPoolPosition ' + startOfConstPoolPosition);
                trace('endOfConstPoolPosition ' + endOfConstPoolPosition);

                swfTag.tagBody.position = 0;

                var newConstPoolByteArray:ByteArray = new ByteArray();
                newConstPoolByteArray.endian = Endian.LITTLE_ENDIAN;

                var abcSerializer:AbcSerializer = new AbcSerializer();
                abcSerializer.serializeConstantPool(cp, newConstPoolByteArray);

                trace("newConstPoolByteArray.length " + newConstPoolByteArray.length);

                var modifiedTagBody:ByteArray = new ByteArray();
                modifiedTagBody.endian = Endian.LITTLE_ENDIAN;
                modifiedTagBody.writeBytes(swfTag.tagBody, 0, startOfConstPoolPosition);
                //modifiedTagBody.writeBytes(swfTag.tagBody, startOfConstPoolPosition, (endOfConstPoolPosition - startOfConstPoolPosition));
                modifiedTagBody.writeBytes(newConstPoolByteArray);
                modifiedTagBody.writeBytes(swfTag.tagBody, endOfConstPoolPosition);


                //trace(HexDump.dumpHex(modifiedTagBody));

                if (modifiedTagBody.length != swfTag.tagBody.length) {
                    // update the recordHeader
                    swfTag.recordHeader = new ByteArray();
                    swfTag.recordHeader.endian = Endian.LITTLE_ENDIAN;
                    swfTag.recordHeader.writeByte(0xbf);
                    swfTag.recordHeader.writeByte(0x14);
                    swfTag.recordHeader.writeInt(modifiedTagBody.length);
                }

                var originalTagBody:ByteArray = swfTag.tagBody;

                swfTag.tagBody = modifiedTagBody;

                originalTagBody.position = 0;
                modifiedTagBody.position = 0;
                for (var i:uint = 0; i < originalTagBody.length; i++)
                {
                    var oB:uint = originalTagBody.readByte();
                    var mB:uint = modifiedTagBody.readByte();
                    if (oB != mB)
                    {
                        trace('i ' + i);
                    }
                }

                swfTag.modified = true;*/
            }
        }

        invokeCallBack();
    }

}
}